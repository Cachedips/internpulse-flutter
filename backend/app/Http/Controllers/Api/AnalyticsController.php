<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomJob;
use App\Models\User;
use App\Services\GeminiException;
use App\Services\GeminiService;
use App\Services\RemotiveService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class AnalyticsController extends Controller
{
    private const EXTRACT_CV_SYSTEM = 'Kamu adalah asisten HR dan karir profesional yang bertugas mengekstrak profil kandidat dari CV. '
        . 'Balas HANYA format JSON valid tanpa tanda markdown atau teks tambahan.';

    private const SKILL_GAP_SYSTEM = 'Kamu adalah konselor karir dan evaluator kesesuaian magang kerja/profesional. '
        . 'Bandingkan keahlian kandidat dengan persyaratan posisi lowongan secara objektif dan realistis. '
        . 'Balas HANYA format JSON valid tanpa tanda markdown atau teks tambahan.';

    public function __construct(
        private GeminiService $gemini,
        private RemotiveService $remotive
    ) {
    }

    /**
     * FITUR 1: POST /api/profile/extract-cv
     * Menerima input cv_text (min 50 char) ATAU cv_file (PDF/TXT).
     * Ekstrak skills (maks 15) dan major dengan Gemini, simpan ke profil user.
     */
    public function extractCv(Request $request): JsonResponse
    {
        @set_time_limit(120);

        try {
            $request->validate([
                'cv_text' => 'nullable|string',
                'cv_file' => 'nullable|file|mimes:pdf,txt|max:5120',
            ], [
                'cv_file.mimes' => 'File CV harus berformat PDF atau TXT.',
                'cv_file.max'   => 'Ukuran file CV maksimal 5MB.',
            ]);

            $cvText = $request->input('cv_text');
            $file   = $request->file('cv_file');

            if (empty($cvText) && ! $file) {
                return response()->json([
                    'message' => 'Harap berikan cv_text (minimal 50 karakter) atau unggah file cv_file (PDF/TXT).',
                ], 422);
            }

            $textToAnalyze = '';
            $base64Pdf     = null;

            if (! empty($cvText)) {
                if (mb_strlen(trim($cvText)) < 50) {
                    return response()->json([
                        'message' => 'Teks CV (cv_text) minimal 50 karakter.',
                    ], 422);
                }
                $textToAnalyze = trim($cvText);
            } elseif ($file) {
                $mime = $file->getMimeType();
                $ext  = strtolower($file->getClientOriginalExtension());

                if ($ext === 'txt' || str_contains($mime, 'text')) {
                    $textToAnalyze = trim((string) file_get_contents($file->getRealPath()));
                } elseif ($ext === 'pdf' || str_contains($mime, 'pdf')) {
                    $extracted = $this->extractTextFromPdf($file->getRealPath());
                    if (mb_strlen($extracted) >= 50) {
                        $textToAnalyze = $extracted;
                    } else {
                        // Fallback kirim konten base64 PDF ke Gemini API
                        $base64Pdf = base64_encode((string) file_get_contents($file->getRealPath()));
                    }
                }

                if (empty($textToAnalyze) && empty($base64Pdf)) {
                    return response()->json([
                        'message' => 'Tidak dapat membaca teks dari file CV yang diunggah. Pastikan file valid dan berisi teks minimal 50 karakter.',
                    ], 422);
                }

                if (! empty($textToAnalyze) && mb_strlen($textToAnalyze) < 50) {
                    return response()->json([
                        'message' => 'Teks dari file CV terlalu pendek (minimal 50 karakter).',
                    ], 422);
                }
            }

            $prompt = "Berikut adalah isi teks CV kandidat:\n"
                . "<cv>\n" . Str::limit($textToAnalyze, 6000, '') . "\n</cv>\n\n"
                . "Tugas:\n"
                . "1. Ekstrak maksimal 15 keahlian (skills) teknis maupun non-teknis yang bersih, spesifik, dan relevan.\n"
                . "2. Identifikasi jurusan atau bidang studi kandidat (major), misalnya 'Teknik Informatika', 'Sistem Informasi', 'Ilmu Komunikasi', 'Manajemen Bisnis', dll.\n\n"
                . "Format JSON yang harus dikembalikan:\n"
                . '{"skills": ["Skill1", "Skill2"], "major": "Nama Jurusan"}';

            $json = null;
            try {
                if ($base64Pdf !== null && empty($textToAnalyze)) {
                    $json = $this->extractFromPdfBase64($base64Pdf);
                } else {
                    $json = $this->callGeminiDirectJson(self::EXTRACT_CV_SYSTEM, $prompt);
                }
            } catch (\Throwable $e) {
                Log::warning('Gemini extract-cv gagal atau timeout: ' . $e->getMessage() . '. Menjalankan fallback lokal PHP.');
                $json = $this->fallbackExtractCv($textToAnalyze, $file ? $file->getRealPath() : null);
            }

            $rawSkills = $json['skills'] ?? [];
            if (! is_array($rawSkills)) {
                $rawSkills = [];
            }

            $skills = collect($rawSkills)
                ->map(fn ($s) => trim((string) $s))
                ->filter(fn ($s) => $s !== '')
                ->unique()
                ->take(15)
                ->values()
                ->all();

            $major = trim((string) ($json['major'] ?? ''));

            $user = $request->user();
            if ($user) {
                $user->user_skills = $skills;

                if (empty($user->major) && $major !== '') {
                    $user->major = $major;
                }

                $user->save();
            }

            return response()->json([
                'message'          => 'CV berhasil diekstrak',
                'user'             => $user ? $user->fresh() : null,
                'extracted_skills' => $skills,
            ], 200);

        } catch (\Illuminate\Validation\ValidationException $ve) {
            return response()->json([
                'message' => $ve->getMessage(),
                'errors'  => $ve->errors(),
            ], 422);
        } catch (\Throwable $e) {
            Log::warning('Gemini extract-cv gagal: ' . $e->getMessage());
            try {
                $fallback = $this->fallbackExtractCv(
                    $request->input('cv_text') ?? '',
                    $request->file('cv_file') ? $request->file('cv_file')->getRealPath() : null
                );
                $user = $request->user();
                if ($user) {
                    $user->user_skills = $fallback['skills'];
                    if (empty($user->major) && ! empty($fallback['major'])) {
                        $user->major = $fallback['major'];
                    }
                    $user->save();
                }
                return response()->json([
                    'message'          => 'CV berhasil diekstrak',
                    'user'             => $user ? $user->fresh() : null,
                    'extracted_skills' => $fallback['skills'],
                ], 200);
            } catch (\Throwable $inner) {
                return response()->json([
                    'message' => $e->getMessage(),
                ], 422);
            }
        }
    }

    /**
     * FITUR 2: POST /api/jobs/skill-gap
     * Menerima job_title, job_description, required_skills (opsional).
     * Bandingkan $user->user_skills dengan kebutuhan lowongan memakai Gemini.
     */
    public function skillGap(Request $request): JsonResponse
    {
        @set_time_limit(120);

        try {
            $data = $request->validate([
                'job_title'        => 'required|string|max:255',
                'job_description'  => 'required|string',
                'required_skills'  => 'nullable',
            ], [
                'job_title.required'       => 'Judul posisi (job_title) wajib diisi.',
                'job_description.required' => 'Deskripsi lowongan (job_description) wajib diisi.',
            ]);

            $user       = $request->user();
            $userSkills = $user->user_skills ?? [];
            if (! is_array($userSkills)) {
                $userSkills = [];
            }

            $skillsList = ! empty($userSkills)
                ? implode(', ', $userSkills)
                : '(Kandidat belum memiliki keahlian tersimpan di profil)';

            $reqSkills = $data['required_skills'] ?? null;
            $reqSkillsStr = ! empty($reqSkills)
                ? (is_array($reqSkills) ? implode(', ', $reqSkills) : (string) $reqSkills)
                : '-';

            $prompt = "Posisi Lowongan: {$data['job_title']}\n"
                . "Keahlian yang Disyaratkan: {$reqSkillsStr}\n"
                . "<deskripsi_lowongan>\n" . Str::limit($data['job_description'], 4000, '') . "\n</deskripsi_lowongan>\n\n"
                . "Daftar Keahlian Kandidat Saat Ini:\n{$skillsList}\n\n"
                . "Bandingkan keahlian kandidat dengan kebutuhan lowongan di atas. Balas HANYA dengan JSON valid:\n"
                . '{"match_percentage": 0-100, "matched_skills": [string], "missing_skills": [string], "recommendation": string}' . "\n\n"
                . "Aturan:\n"
                . "- match_percentage: integer 0 sampai 100 yang merefleksikan tingkat kesiapan kandidat.\n"
                . "- matched_skills: array string berisi keahlian kandidat yang cocok dengan kebutuhan lowongan.\n"
                . "- missing_skills: array string berisi keahlian penting yang belum dimiliki kandidat.\n"
                . "- recommendation: string singkat (2-3 kalimat Bahasa Indonesia) berupa saran konkret langkah belajar.";

            $json = null;
            try {
                $json = $this->callGeminiDirectJson(self::SKILL_GAP_SYSTEM, $prompt);
            } catch (\Throwable $e) {
                Log::warning('Gemini skill-gap API gagal atau timeout: ' . $e->getMessage() . '. Menjalankan fallback lokal PHP.');
                $json = $this->fallbackSkillGap($data, $userSkills);
            }

            $matchPercentage = isset($json['match_percentage'])
                ? max(0, min(100, (int) round((float) $json['match_percentage'])))
                : 0;

            $matchedSkills = isset($json['matched_skills']) && is_array($json['matched_skills'])
                ? array_values(array_filter(array_map('trim', $json['matched_skills']), fn ($s) => $s !== ''))
                : [];

            $missingSkills = isset($json['missing_skills']) && is_array($json['missing_skills'])
                ? array_values(array_filter(array_map('trim', $json['missing_skills']), fn ($s) => $s !== ''))
                : [];

            $recommendation = isset($json['recommendation'])
                ? trim((string) $json['recommendation'])
                : '';

            $responsePayload = [
                'match_percentage' => $matchPercentage,
                'matched_skills'   => $matchedSkills,
                'missing_skills'   => $missingSkills,
                'recommendation'   => $recommendation,
            ];

            return response()->json($responsePayload + ['data' => $responsePayload], 200);

        } catch (\Illuminate\Validation\ValidationException $ve) {
            return response()->json([
                'message' => $ve->getMessage(),
                'errors'  => $ve->errors(),
            ], 422);
        } catch (\Throwable $e) {
            Log::warning('skillGap error: ' . $e->getMessage());
            $fb = $this->fallbackSkillGap([
                'job_title'        => (string) $request->input('job_title', 'Posisi Lowongan'),
                'job_description'  => (string) $request->input('job_description', ''),
                'required_skills'  => $request->input('required_skills', null),
            ], $request->user()?->user_skills ?? []);

            return response()->json($fb + ['data' => $fb], 200);
        }
    }

    /**
     * FITUR 3: GET /api/analytics/market-trends
     * Gabungkan CustomJob aktif dengan data cache RemotiveService.
     * Hitung total_jobs, stipend_breakdown, location_breakdown, dan 8 top_skills di PHP secara instan.
     */
    public function marketTrends(Request $request): JsonResponse
    {
        @set_time_limit(120);

        try {
            $allJobs = $this->getAllActiveJobs();
            $totalJobs = $allJobs->count();

            // 1. Stipend Breakdown (paid vs unpaid/unspecified)
            $paidCount   = 0;
            $unpaidCount = 0;
            foreach ($allJobs as $job) {
                $stipend = mb_strtolower((string) ($job['stipend_type'] ?? ''));
                if ($stipend === 'paid' || $stipend === 'allowance' || ! empty($job['salary_range'])) {
                    $paidCount++;
                } else {
                    $unpaidCount++;
                }
            }

            $stipendBreakdown = [
                'paid'   => $paidCount,
                'unpaid' => $unpaidCount,
            ];

            // 2. Location Breakdown (remote vs onsite/hybrid)
            $remoteCount       = 0;
            $onsiteHybridCount = 0;
            $onsiteCount       = 0;
            $hybridCount       = 0;

            foreach ($allJobs as $job) {
                $loc = mb_strtolower((string) ($job['location'] ?? ''));
                if (str_contains($loc, 'remote') || ($job['location'] ?? '') === 'Remote') {
                    $remoteCount++;
                } elseif (str_contains($loc, 'hybrid')) {
                    $hybridCount++;
                    $onsiteHybridCount++;
                } else {
                    $onsiteCount++;
                    $onsiteHybridCount++;
                }
            }

            $locationBreakdown = [
                'remote'        => $remoteCount,
                'onsite_hybrid' => $onsiteHybridCount,
                'onsite'        => $onsiteCount,
                'hybrid'        => $hybridCount,
            ];

            // 3. 8 Top Skills Teratas
            $topSkills = $this->calculateTopSkills($allJobs, 8);

            return response()->json([
                'data' => [
                    'total_jobs'         => (int) $totalJobs,
                    'stipend_breakdown'  => $stipendBreakdown,
                    'location_breakdown' => $locationBreakdown,
                    'top_skills'         => $topSkills,
                ],
            ], 200);
        } catch (\Throwable $e) {
            Log::error('marketTrends error: ' . $e->getMessage());
            return response()->json([
                'data' => [
                    'total_jobs'         => 0,
                    'stipend_breakdown'  => [
                        'paid'   => 0,
                        'unpaid' => 0,
                    ],
                    'location_breakdown' => [
                        'remote'        => 0,
                        'onsite_hybrid' => 0,
                        'onsite'        => 0,
                        'hybrid'        => 0,
                    ],
                    'top_skills'         => [],
                ],
                'error' => $e->getMessage(),
            ], 200);
        }
    }

    /**
     * FITUR 4: GET /api/analytics/skill-scarcity
     * Hitung Demand Rate, Supply Rate, Scarcity Index, Kategori, dan user_has_skill.
     */
    public function skillScarcity(Request $request): JsonResponse
    {
        @set_time_limit(120);

        try {
            $allJobs = $this->getAllActiveJobs();
            $totalJobs = $allJobs->count();

            // Ambil keahlian seluruh kandidat
            $candidates = User::whereNotNull('user_skills')->get(['id', 'user_skills']);
            $totalCandidates = $candidates->count();

            // Skill milik user login
            $currentUserSkills = $request->user()?->user_skills ?? [];
            if (! is_array($currentUserSkills)) {
                $currentUserSkills = [];
            }
            $userSkillsLower = array_map(fn ($s) => mb_strtolower(trim((string) $s)), $currentUserSkills);

            // Kumpulan kata kunci keahlian untuk dianalisis
            $skillDictionary = $this->getSkillPatterns();

            // Masukkan juga skill unik dari kandidat yang belum ada di kamus
            foreach ($candidates as $c) {
                if (is_array($c->user_skills)) {
                    foreach ($c->user_skills as $sk) {
                        $trimmed = trim((string) $sk);
                        if ($trimmed !== '' && ! isset($skillDictionary[$trimmed])) {
                            $quoted = preg_quote($trimmed, '/');
                            $skillDictionary[$trimmed] = '/(?:\b|(?<=[\s,.\/]|^))' . $quoted . '(?:\b|(?=[\s,.\/]|$))/i';
                        }
                    }
                }
            }

            // 1. Hitung Demand per skill
            $demandCounts = [];
            foreach ($allJobs as $job) {
                $text = ($job['job_title'] ?? '') . ' ' . ($job['job_requirements'] ?? '');
                foreach ($skillDictionary as $skillName => $regex) {
                    if (@preg_match($regex, $text)) {
                        $demandCounts[$skillName] = ($demandCounts[$skillName] ?? 0) + 1;
                    }
                }
            }

            // 2. Hitung Supply per skill
            $supplyCounts = [];
            foreach ($candidates as $c) {
                if (! is_array($c->user_skills)) {
                    continue;
                }
                $cSkillsLower = array_map(fn ($s) => mb_strtolower(trim((string) $s)), $c->user_skills);

                foreach ($skillDictionary as $skillName => $regex) {
                    $nameLower = mb_strtolower($skillName);
                    if (in_array($nameLower, $cSkillsLower, true)) {
                        $supplyCounts[$skillName] = ($supplyCounts[$skillName] ?? 0) + 1;
                    }
                }
            }

            // 3. Hitung Metrics tiap skill
            $list = [];
            foreach ($skillDictionary as $skillName => $regex) {
                $demandCount = (int) ($demandCounts[$skillName] ?? 0);
                $supplyCount = (int) ($supplyCounts[$skillName] ?? 0);

                // Jangan masukkan skill yang tidak memiliki demand sama sekali
                if ($demandCount === 0 && $supplyCount === 0) {
                    continue;
                }

                $demandRate = $totalJobs > 0
                    ? round(($demandCount / $totalJobs) * 100, 2)
                    : 0.0;

                $supplyRate = $totalCandidates > 0
                    ? round(($supplyCount / $totalCandidates) * 100, 2)
                    : 0.0;

                $denominator = $supplyRate + 1.0;
                $scarcityIndex = $denominator > 0 ? round($demandRate / $denominator, 2) : 0.0;

                // Klasifikasi Kategori
                if ($demandRate >= 10 && $scarcityIndex >= 1.5) {
                    $category = 'High Opportunity';
                } elseif ($demandRate >= 10 && $scarcityIndex < 1.5) {
                    $category = 'Competitive';
                } else {
                    $category = 'Niche';
                }

                $userHasSkill = in_array(mb_strtolower($skillName), $userSkillsLower, true);

                $list[] = [
                    'skill'          => (string) $skillName,
                    'demand_count'   => $demandCount,
                    'demand_rate'    => (float) $demandRate,
                    'supply_count'   => $supplyCount,
                    'supply_rate'    => (float) $supplyRate,
                    'scarcity_index' => (float) $scarcityIndex,
                    'category'       => (string) $category,
                    'user_has_skill' => (bool) $userHasSkill,
                ];
            }

            // 4. Urutkan berdasarkan scarcity_index tertinggi, lalu demand_rate desc
            usort($list, function ($a, $b) {
                if ($b['scarcity_index'] != $a['scarcity_index']) {
                    return $b['scarcity_index'] <=> $a['scarcity_index'];
                }
                return $b['demand_rate'] <=> $a['demand_rate'];
            });

            // Ambil top 12
            $top12 = array_slice($list, 0, 12);

            return response()->json([
                'data' => $top12,
            ], 200);
        } catch (\Throwable $e) {
            Log::error('skillScarcity error: ' . $e->getMessage());
            return response()->json([
                'data' => [],
                'error' => $e->getMessage(),
            ], 200);
        }
    }

    /**
     * Ambil gabungan seluruh lowongan aktif (CustomJob + Remotive cache).
     * Dilengkapi timeout singkat (maks 3-4 detik) dan fallback instan agar respons selesai di bawah 1 detik.
     */
    private function getAllActiveJobs(): Collection
    {
        try {
            $localJobs = CustomJob::where('is_active', true)
                ->latest()
                ->get()
                ->map(function (CustomJob $j) {
                    return [
                        'id'               => 'local-' . $j->id,
                        'source'           => 'local',
                        'company_name'     => $j->company_name,
                        'job_title'        => $j->job_title,
                        'location'         => $j->location ?: 'Lokal',
                        'major_category'   => $j->major_category,
                        'stipend_type'     => $j->stipend_type ?: 'unknown',
                        'salary_range'     => $j->salary_range,
                        'job_requirements' => (string) $j->job_requirements,
                        'job_url'          => $j->application_link,
                    ];
                });
        } catch (\Throwable $e) {
            Log::warning('Analytics local jobs error: ' . $e->getMessage());
            $localJobs = collect();
        }

        $globalJobs = collect();
        try {
            // 1. Cek cache terlebih dahulu agar respons instan (< 10ms)
            $cached = Cache::get('remotive_internships');
            if (is_array($cached) && ! empty($cached)) {
                $globalJobs = collect($cached);
            } else {
                // 2. Jika cache belum ada, coba fetch cepat dengan timeout maks 5 detik & fallback []
                $response = Http::withoutVerifying()
                    ->timeout(5)
                    ->connectTimeout(2)
                    ->acceptJson()
                    ->get('https://remotive.com/api/remote-jobs', [
                        'search' => 'intern',
                        'limit'  => 80,
                    ]);

                if ($response->successful()) {
                    $rawJobs = $response->json('jobs', []);
                    if (is_array($rawJobs) && ! empty($rawJobs)) {
                        $mapped = collect($rawJobs)->map(function ($j) {
                            $title  = (string) ($j['title'] ?? '-');
                            $desc   = strip_tags((string) ($j['description'] ?? ''));
                            $salary = trim((string) ($j['salary'] ?? ''));
                            return [
                                'id'               => 'remotive-' . ($j['id'] ?? Str::random(6)),
                                'source'           => 'remotive',
                                'company_name'     => $j['company_name'] ?? '-',
                                'job_title'        => $title,
                                'location'         => 'Remote',
                                'major_category'   => 'Informatika/SI',
                                'stipend_type'     => ! empty($salary) ? 'paid' : 'unpaid',
                                'salary_range'     => $salary !== '' ? $salary : null,
                                'job_requirements' => Str::limit($desc, 3000),
                                'job_url'          => $j['url'] ?? null,
                            ];
                        })->values()->all();

                        Cache::put('remotive_internships', $mapped, 21600);
                        $globalJobs = collect($mapped);
                    }
                }
            }
        } catch (\Throwable $e) {
            // Fallback aman jika external API timeout atau unreachable
            Log::warning('Analytics remotive fetch timeout/error, fallback empty: ' . $e->getMessage());
            $globalJobs = collect();
        }

        return $localJobs->concat($globalJobs);
    }

    /**
     * Hitung 8 skill terbanyak dicari dari kumpulan lowongan.
     */
    private function calculateTopSkills(Collection $jobs, int $limit = 8): array
    {
        try {
            $patterns = $this->getSkillPatterns();
            $counts   = [];

            foreach ($jobs as $job) {
                $text = ($job['job_title'] ?? '') . ' ' . ($job['job_requirements'] ?? '');
                foreach ($patterns as $skill => $regex) {
                    if (@preg_match($regex, $text)) {
                        $counts[$skill] = ($counts[$skill] ?? 0) + 1;
                    }
                }
            }

            arsort($counts);

            $result = [];
            $i = 0;
            foreach ($counts as $skill => $count) {
                if ($i >= $limit) {
                    break;
                }
                $result[] = [
                    'skill' => (string) $skill,
                    'count' => (int) $count,
                ];
                $i++;
            }

            return $result;
        } catch (\Throwable $e) {
            Log::warning('calculateTopSkills error: ' . $e->getMessage());
            return [];
        }
    }

    /**
     * Kamus pola regex keahlian teknis/tools industri.
     */
    private function getSkillPatterns(): array
    {
        return $this->getComprehensiveSkillPatterns();
    }

    /**
     * Fallback ekstraksi CV lokal di PHP jika Gemini API timeout atau gagal merespons.
     * Mencocokkan teks CV (baik dari input teks maupun parsing PDF) terhadap daftar lengkap
     * skill teknologi, data, AI, dan bisnis serta mendeteksi jurusan kandidat.
     */
    private function fallbackExtractCv(string $text, ?string $filePath = null): array
    {
        $rawText = $text;
        if (empty($rawText) && $filePath && file_exists($filePath)) {
            $rawText = $this->extractTextFromPdf($filePath);
            if (empty($rawText)) {
                $rawText = (string) @file_get_contents($filePath);
            }
        }

        $patterns = $this->getComprehensiveSkillPatterns();
        $matched = [];

        // Scan teks terhadap pola keahlian dan catat urutan kemunculan di CV
        foreach ($patterns as $skill => $regex) {
            if (@preg_match($regex, $rawText, $m, PREG_OFFSET_CAPTURE)) {
                $matched[$skill] = $m[0][1];
            }
        }

        asort($matched);
        $matchedSkills = array_keys($matched);

        // Jika tidak ada skill yang cocok (misalnya file PDF gambar murni), sediakan fallback default
        if (empty($matchedSkills)) {
            $matchedSkills = [
                'Problem Solving',
                'Communication',
                'Teamwork',
                'Project Management',
                'Git',
                'Data Analysis',
            ];
        }

        // Ambil maksimal 15 keahlian unik
        $finalSkills = array_values(array_unique(array_slice($matchedSkills, 0, 15)));

        // Deteksi jurusan (major)
        $majorPatterns = [
            'Teknik Informatika'        => '/\b(teknik informatika|informatics|computer science|ilmu komputer)\b/i',
            'Sistem Informasi'          => '/\b(sistem informasi|information systems?)\b/i',
            'Sains Data'                => '/\b(sains data|data science)\b/i',
            'Teknologi Informasi'       => '/\b(teknologi informasi|information technology)\b/i',
            'Teknik Komputer'           => '/\b(teknik komputer|computer engineering)\b/i',
            'Teknik Elektro'            => '/\b(teknik elektro|electrical engineering)\b/i',
            'Rekayasa Perangkat Lunak'  => '/\b(rpl|rekayasa perangkat lunak|software engineering)\b/i',
            'Manajemen Bisnis'          => '/\b(manajemen bisnis|business management|manajemen)\b/i',
            'Bisnis Digital'            => '/\b(bisnis digital|digital business)\b/i',
            'Akuntansi'                 => '/\b(akuntansi|accounting)\b/i',
            'Ilmu Komunikasi'           => '/\b(ilmu komunikasi|communication science|komunikasi)\b/i',
            'Desain Komunikasi Visual'  => '/\b(dkv|desain komunikasi visual|visual communication design)\b/i',
            'Statistika'                => '/\b(statistika|statistics)\b/i',
            'Matematika'                => '/\b(matematika|mathematics)\b/i',
        ];

        $detectedMajor = '';
        foreach ($majorPatterns as $majorName => $mRegex) {
            if (@preg_match($mRegex, $rawText)) {
                $detectedMajor = $majorName;
                break;
            }
        }

        return [
            'skills' => $finalSkills,
            'major'  => $detectedMajor,
        ];
    }

    /**
     * Fallback analisis kesenjangan skill lokal jika Gemini API timeout atau gagal.
     */
    private function fallbackSkillGap(array $data, array $userSkills): array
    {
        $allPatterns = $this->getComprehensiveSkillPatterns();
        $jobText = ($data['job_title'] ?? '') . ' ' . ($data['job_description'] ?? '') . ' ' . (is_array($data['required_skills'] ?? null) ? implode(' ', $data['required_skills']) : (string) ($data['required_skills'] ?? ''));

        $requiredDetected = [];
        if (! empty($data['required_skills'])) {
            $rawReq = is_array($data['required_skills']) ? $data['required_skills'] : explode(',', (string) $data['required_skills']);
            foreach ($rawReq as $r) {
                $trimmed = trim((string) $r);
                if ($trimmed !== '') {
                    $requiredDetected[] = $trimmed;
                }
            }
        }

        foreach ($allPatterns as $skillName => $regex) {
            if (@preg_match($regex, $jobText)) {
                $requiredDetected[] = $skillName;
            }
        }
        $requiredDetected = array_values(array_unique($requiredDetected));
        if (empty($requiredDetected)) {
            $requiredDetected = ['Communication', 'Problem Solving', 'Teamwork'];
        }

        $userSkillsLower = array_map(fn ($s) => mb_strtolower(trim((string) $s)), $userSkills);

        $matchedSkills = [];
        $missingSkills = [];

        foreach ($requiredDetected as $reqSkill) {
            $reqLower = mb_strtolower($reqSkill);
            $found = false;
            foreach ($userSkillsLower as $uSkill) {
                if ($uSkill === $reqLower || str_contains($uSkill, $reqLower) || str_contains($reqLower, $uSkill)) {
                    $found = true;
                    break;
                }
            }
            if ($found) {
                $matchedSkills[] = $reqSkill;
            } else {
                $missingSkills[] = $reqSkill;
            }
        }

        $total = count($matchedSkills) + count($missingSkills);
        $percentage = $total > 0 ? (int) round((count($matchedSkills) / $total) * 100) : 25;

        if (count($missingSkills) > 0 && $percentage > 90) {
            $percentage = 90;
        }

        $jobTitle = $data['job_title'] ?? 'posisi ini';
        if ($percentage >= 75) {
            $missingStr = ! empty($missingSkills) ? implode(', ', array_slice($missingSkills, 0, 2)) : 'teknologi lanjutan';
            $rec = "Keahlian Anda sangat cocok dengan lowongan {$jobTitle}. Kuasai juga {$missingStr} untuk memaksimalkan peluang lolos seleksi magang.";
        } elseif ($percentage >= 45) {
            $missingStr = ! empty($missingSkills) ? implode(', ', array_slice($missingSkills, 0, 3)) : 'keahlian pendukung';
            $rec = "Anda memiliki fondasi yang cukup baik untuk posisi {$jobTitle}. Disarankan memperdalam {$missingStr} sebelum melamar.";
        } else {
            $missingStr = ! empty($missingSkills) ? implode(', ', array_slice($missingSkills, 0, 3)) : 'keahlian teknis inti';
            $rec = "Tingkat kesesuaian keahlian masih perlu ditingkatkan untuk {$jobTitle}. Fokuslah mempelajari {$missingStr} melalui kursus dan proyek portofolio.";
        }

        return [
            'match_percentage' => $percentage,
            'matched_skills'   => array_values($matchedSkills),
            'missing_skills'   => array_values($missingSkills),
            'recommendation'   => $rec,
        ];
    }

    /**
     * Kamus lengkap pola regex keahlian teknologi, data, AI, dan bisnis.
     */
    private function getComprehensiveSkillPatterns(): array
    {
        return [
            // AI, Machine Learning & Data
            'Python'                      => '/\bpython\b/i',
            'SQL'                         => '/\bsql\b/i',
            'Exploratory Data Analysis'   => '/\b(exploratory data analysis|eda)\b/i',
            'Data Visualization'          => '/\bdata visuali[zs]ation\b/i',
            'AI Engineering'              => '/\bai engineering\b/i',
            'Machine Learning'            => '/\b(machine[\s\-]learning|ml)\b/i',
            'Deep Learning'               => '/\bdeep[\s\-]learning\b/i',
            'Data Science'                => '/\bdata[\s\-]science\b/i',
            'Artificial Intelligence'     => '/\b(artificial intelligence|kecerdasan buatan)\b/i',
            'CNN'                         => '/\b(cnn|convolutional neural network(s)?)\b/i',
            'LLM'                         => '/\b(llm|large language model(s)?)\b/i',
            'Natural Language Processing' => '/\b(nlp|natural language processing)\b/i',
            'Computer Vision'             => '/\bcomputer vision\b/i',
            'Prompt Engineering'          => '/\bprompt engineering\b/i',
            'Generative AI'               => '/\b(generative ai|gen[\s\-]?ai)\b/i',
            'TensorFlow'                  => '/\btensorflow\b/i',
            'PyTorch'                     => '/\bpytorch\b/i',
            'Scikit-Learn'                => '/\bscikit[\s\-]learn\b/i',
            'Pandas'                      => '/\bpandas\b/i',
            'NumPy'                       => '/\bnumpy\b/i',
            'Matplotlib'                  => '/\bmatplotlib\b/i',
            'Seaborn'                     => '/\bseaborn\b/i',
            'Tableau'                     => '/\btableau\b/i',
            'Power BI'                    => '/\bpower[\s\-]?bi\b/i',
            'Data Analysis'               => '/\bdata analy(sis|st|tics)\b/i',
            'Big Data'                    => '/\bbig[\s\-]data\b/i',
            'Apache Spark'                => '/\b(apache\s*)?spark\b/i',
            'Statistics'                  => '/\b(statistics|statistika)\b/i',

            // Backend & Programming
            'PHP'                         => '/\bphp\b/i',
            'Laravel'                     => '/\blaravel\b/i',
            'CodeIgniter'                 => '/\bcodeigniter\b/i',
            'Node.js'                     => '/\bnode(\.js)?\b/i',
            'Express.js'                  => '/\bexpress(\.js)?\b/i',
            'NestJS'                      => '/\bnest(\.js)?\b/i',
            'Django'                      => '/\bdjango\b/i',
            'FastAPI'                     => '/\bfastapi\b/i',
            'Flask'                       => '/\bflask\b/i',
            'Java'                        => '/\bjava\b(?!\s*script)/i',
            'Spring Boot'                 => '/\bspring(\s*boot)?\b/i',
            'Go / Golang'                 => '/\b(golang|go\s+language)\b/i',
            'C++'                         => '/\bc\+\+\b/i',
            'C#'                          => '/\bc#|\bc\s*sharp\b/i',
            'REST API'                    => '/\brest(ful)?\s*api\b/i',
            'GraphQL'                     => '/\bgraphql\b/i',

            // Frontend & Mobile
            'Flutter'                     => '/\bflutter\b/i',
            'Dart'                        => '/\bdart\b/i',
            'React'                       => '/\breact(\.js)?\b(?!\s*native)/i',
            'React Native'                => '/\breact[\s\-]native\b/i',
            'JavaScript'                  => '/\b(javascript|js)\b/i',
            'TypeScript'                  => '/\b(typescript|ts)\b/i',
            'Vue.js'                      => '/\bvue(\.js)?\b/i',
            'Next.js'                     => '/\bnext(\.js)?\b/i',
            'HTML / CSS'                  => '/\b(html5?|css3?)\b/i',
            'Tailwind CSS'                => '/\btailwind(\s*css)?\b/i',
            'Bootstrap'                   => '/\bbootstrap\b/i',
            'Android Development'         => '/\bandroid(\s*dev|\s*development)?\b/i',
            'Kotlin'                      => '/\bkotlin\b/i',
            'Swift'                       => '/\bswift\b/i',
            'iOS Development'             => '/\bios(\s*dev|\s*development)?\b/i',

            // Database, Cloud, DevOps
            'MySQL'                       => '/\bmysql\b/i',
            'PostgreSQL'                  => '/\bpostgres(ql)?\b/i',
            'MongoDB'                     => '/\bmongo(db)?\b/i',
            'Redis'                       => '/\bredis\b/i',
            'Firebase'                    => '/\bfirebase\b/i',
            'Git'                         => '/\bgit(hub|lab)?\b/i',
            'Docker'                      => '/\bdocker\b/i',
            'Kubernetes'                  => '/\b(kubernetes|k8s)\b/i',
            'CI / CD'                     => '/\bci[\/\s\-]?cd\b/i',
            'Linux'                       => '/\blinux\b/i',
            'AWS'                         => '/\b(aws|amazon web services)\b/i',
            'GCP'                         => '/\b(gcp|google cloud)\b/i',
            'Azure'                       => '/\bazure\b/i',

            // Design, Business & Soft Skills
            'UI / UX'                     => '/\bui[\/\s\-]?ux\b/i',
            'Figma'                       => '/\bfigma\b/i',
            'Excel'                       => '/\b(excel|spreadsheets?)\b/i',
            'Business Analysis'           => '/\bbusiness analy(sis|st)\b/i',
            'Project Management'          => '/\bproject management\b/i',
            'Product Management'          => '/\bproduct management\b/i',
            'Agile / Scrum'               => '/\b(agile|scrum)\b/i',
            'Digital Marketing'           => '/\bdigital marketing\b/i',
            'SEO'                         => '/\b(seo|search engine optimization)\b/i',
            'Copywriting'                 => '/\b(copywriting|copywriter|content writing)\b/i',
            'Public Speaking'             => '/\bpublic speaking\b/i',
            'Communication'               => '/\bcommunication\b|\bkomunikasi\b/i',
            'Teamwork'                    => '/\bteamwork\b|\bkerja\s*tim\b/i',
            'Problem Solving'             => '/\bproblem[\s\-]solving\b/i',
            'Critical Thinking'           => '/\bcritical thinking\b/i',
        ];
    }

    /**
     * Ekstraksi teks sederhana dari file PDF murni tanpa library eksternal.
     */
    private function extractTextFromPdf(string $filePath): string
    {
        $content = @file_get_contents($filePath);
        if (! $content) {
            return '';
        }

        $text = '';
        if (preg_match_all('/stream[\r\n]+(.*?)[\r\n]+endstream/s', $content, $matches)) {
            foreach ($matches[1] as $stream) {
                $uncompressed = @gzuncompress($stream);
                if ($uncompressed === false) {
                    $uncompressed = $stream;
                }

                if (preg_match_all('/\((.*?)\)\s*T[jJ]/s', $uncompressed, $textMatches)) {
                    $text .= implode(' ', $textMatches[1]) . "\n";
                } elseif (preg_match_all('/\[(.*?)\]\s*TJ/s', $uncompressed, $tjMatches)) {
                    foreach ($tjMatches[1] as $tj) {
                        if (preg_match_all('/\((.*?)\)/s', $tj, $subMatches)) {
                            $text .= implode('', $subMatches[1]) . ' ';
                        }
                    }
                    $text .= "\n";
                }
            }
        }

        if (trim($text) === '') {
            $printable = preg_replace('/[^\x20-\x7E\r\n\t]/', ' ', $content);
            $text = preg_replace('/\s+/', ' ', (string) $printable);
        }

        $text = preg_replace_callback('/\\\\([0-7]{1,3})/', fn ($m) => chr(octdec($m[1])), $text);
        $text = str_replace(['\\(', '\\)', '\\\\'], ['(', ')', '\\'], $text);
        $text = preg_replace('/[ \t]+/', ' ', $text);
        $text = preg_replace("/\n{3,}/", "\n\n", $text);

        return trim($text);
    }

    /**
     * Panggilan langsung ke Gemini API menggunakan Http::withoutVerifying()->timeout(12)
     * dan opsi IPv4 agar aman dari error SSL & DNS cURL di Windows.
     */
    private function callGeminiDirectJson(string $system, string $prompt): array
    {
        $key   = (string) env('GEMINI_API_KEY', '');
        if ($key === '') {
            throw new \Exception('GEMINI_API_KEY belum disetel di file .env backend.');
        }

        $model = (string) env('GEMINI_MODEL', 'gemini-2.5-flash');

        $payload = [
            'systemInstruction' => ['parts' => [['text' => $system]]],
            'contents'          => [['role' => 'user', 'parts' => [['text' => $prompt]]]],
            'generationConfig'  => [
                'temperature'      => 0.3,
                'responseMimeType' => 'application/json',
                'maxOutputTokens'  => 8192,
            ],
        ];

        $response = Http::withoutVerifying()
            ->withOptions([
                'curl' => [
                    CURLOPT_IPRESOLVE => CURL_IPRESOLVE_V4,
                ],
            ])
            ->timeout(12)
            ->withHeaders(['x-goog-api-key' => $key])
            ->acceptJson()
            ->asJson()
            ->post('https://generativelanguage.googleapis.com/v1beta/models/' . $model . ':generateContent', $payload);
    
        if (! $response->successful()) {
            throw new \Exception('Gemini API HTTP ' . $response->status() . ': ' . $response->body());
        }

        $parts = $response->json('candidates.0.content.parts', []);
        $raw = collect($parts)->reject(fn ($p) => ! empty($p['thought']))->pluck('text')->implode('');

        $clean = trim(preg_replace('/^```(?:json)?\s*|\s*```$/i', '', trim($raw)));
        $decoded = json_decode($clean, true);

        if (! is_array($decoded)) {
            $start = strpos($clean, '{');
            $end   = strrpos($clean, '}');
            if ($start !== false && $end !== false && $end > $start) {
                $decoded = json_decode(substr($clean, $start, $end - $start + 1), true);
            }
        }

        if (! is_array($decoded)) {
            throw new \Exception('Respon Gemini tidak valid atau bukan JSON.');
        }

        return $decoded;
    }

    /**
     * Panggilan langsung ke Gemini API dengan inline_data base64 PDF.
     * Menggunakan Http::withoutVerifying()->timeout(12) dan opsi IPv4 agar aman dari error SSL & DNS cURL di Windows.
     */
    private function extractFromPdfBase64(string $base64Pdf): array
    {
        $key   = (string) env('GEMINI_API_KEY', '');
        if ($key === '') {
            throw new \Exception('GEMINI_API_KEY belum disetel di file .env backend.');
        }

        $model = (string) env('GEMINI_MODEL', 'gemini-2.5-flash');

        $prompt = "Berikut adalah file PDF CV kandidat. Ekstrak informasi berikut:\n"
            . "1. skills: maksimal 15 keahlian (skills) teknis maupun non-teknis yang bersih dan relevan.\n"
            . "2. major: jurusan atau bidang studi kandidat.\n\n"
            . "Format JSON yang harus dikembalikan:\n"
            . '{"skills": ["Skill1", "Skill2"], "major": "Nama Jurusan"}';

        $payload = [
            'systemInstruction' => ['parts' => [['text' => self::EXTRACT_CV_SYSTEM]]],
            'contents' => [
                [
                    'role'  => 'user',
                    'parts' => [
                        [
                            'inline_data' => [
                                'mime_type' => 'application/pdf',
                                'data'      => $base64Pdf,
                            ],
                        ],
                        [
                            'text' => $prompt,
                        ],
                    ],
                ],
            ],
            'generationConfig' => [
                'temperature'      => 0.3,
                'responseMimeType' => 'application/json',
                'maxOutputTokens'  => 4096,
            ],
        ];

        $response = Http::withoutVerifying()
            ->withOptions([
                'curl' => [
                    CURLOPT_IPRESOLVE => CURL_IPRESOLVE_V4,
                ],
            ])
            ->timeout(12)
            ->withHeaders(['x-goog-api-key' => $key])
            ->acceptJson()
            ->asJson()
            ->post('https://generativelanguage.googleapis.com/v1beta/models/' . $model . ':generateContent', $payload);

        if (! $response->successful()) {
            throw new \Exception('Gemini API HTTP ' . $response->status() . ': ' . $response->body());
        }

        $parts = $response->json('candidates.0.content.parts', []);
        $raw = collect($parts)->reject(fn ($p) => ! empty($p['thought']))->pluck('text')->implode('');

        $clean = trim(preg_replace('/^```(?:json)?\s*|\s*```$/i', '', trim($raw)));
        $decoded = json_decode($clean, true);

        if (! is_array($decoded)) {
            $start = strpos($clean, '{');
            $end   = strrpos($clean, '}');
            if ($start !== false && $end !== false && $end > $start) {
                $decoded = json_decode(substr($clean, $start, $end - $start + 1), true);
            }
        }

        if (! is_array($decoded)) {
            throw new \Exception('Respon Gemini tidak valid atau bukan JSON.');
        }

        return $decoded;
    }
}
