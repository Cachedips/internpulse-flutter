<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomJob;
use App\Models\User;
use Database\Seeders\CustomJobSeeder;
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
    private const EXTRACT_CV_SYSTEM = 'Kamu adalah Universal HR Specialist & Senior Career Analyst profesional. '
        . 'Tugasmu adalah membaca, mengekstrak, dan menganalisis CV/Resume kandidat dari segala bidang keilmuan (Teknologi, Data, Bisnis, Manajemen, Keuangan, Akuntansi, Marketing, Desain, Komunikasi, Teknik, Hukum, Kesehatan, Pendidikan, Operasional, dll.) secara objektif, akurat, dan realistis berdasarkan informasi nyata yang tertera pada CV. '
        . 'Jangan mengarang informasi atau keahlian yang tidak ada di dalam dokumen. '
        . 'Balas HANYA format JSON valid tanpa tanda markdown (```json ... ```) atau teks pengantar lainnya.';

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
     * Universal AI CV Reader & Analyzer:
     * Menerima input cv_text (min 50 char) ATAU cv_file (PDF/TXT).
     * Jika file .pdf diunggah, ekstrak teks bersih terlebih dahulu dengan \Smalot\PdfParser\Parser,
     * lalu kirim teks bersih tersebut ke Gemini API sebagai teks biasa (hemat kuota token).
     */
    public function extractCv(Request $request): JsonResponse
    {
        @set_time_limit(120);

        $textToAnalyze = '';

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

            $instructionPrompt = "Tugas Anda adalah membaca dan menganalisis seluruh isi CV/Resume ini secara mendalam dan menyeluruh.\n"
                . "Kembalikan respon HANYA dalam format JSON valid dengan struktur persis berikut:\n"
                . "{\n"
                . '  "skills": ["Skill1", "Skill2", "Skill3", ...],' . "\n"
                . '  "major": "Nama Jurusan / Bidang Studi Kandidat",' . "\n"
                . '  "analysis": {' . "\n"
                . '    "summary": "Ringkasan profesional kandidat (2-3 kalimat Bahasa Indonesia) yang merefleksikan profil, latar belakang, dan keahlian intinya.",' . "\n"
                . '    "strengths": [' . "\n"
                . '      "Poin kekuatan utama 1 berdasarkan pengalaman/proyek/prestasi nyata di CV",' . "\n"
                . '      "Poin kekuatan utama 2 berdasarkan pengalaman/proyek/prestasi nyata di CV",' . "\n"
                . '      "Poin kekuatan utama 3 berdasarkan pengalaman/proyek/prestasi nyata di CV"' . "\n"
                . '    ],' . "\n"
                . '    "improvements": [' . "\n"
                . '      "Saran konkret 1 untuk meningkatkan kualitas CV atau portofolio",' . "\n"
                . '      "Saran konkret 2 untuk meningkatkan kualitas CV atau portofolio"' . "\n"
                . '    ],' . "\n"
                . '    "recommended_roles": [' . "\n"
                . '      "Nama Posisi 1",' . "\n"
                . '      "Nama Posisi 2",' . "\n"
                . '      "Nama Posisi 3"' . "\n"
                . '    ]' . "\n"
                . "  }\n"
                . "}\n\n"
                . "Ketentuan Ketat:\n"
                . "1. 'skills': Ekstrak SEMUA keahlian nyata yang tertulis di dalam CV (hard skills, software, tools, teknologi, metode, bahasa asing, dan soft skills). Jangan batasi hanya 4-5 item, keluarkan semua yang tertulis. JANGAN MENGARANG atau menambahkan keahlian yang tidak tertulis di CV.\n"
                . "2. 'major': Tuliskan nama jurusan / program studi kandidat (misal: 'Teknik Informatika', 'Sistem Informasi', 'Manajemen', 'Akuntansi', 'Ilmu Komunikasi', 'Hukum', 'Farmasi', 'Teknik Mesin', dll.). Jika tidak tertulis eksplisit, tentukan bidang keilmuan yang paling relevan.\n"
                . "3. 'analysis.summary': 2-3 kalimat ringkas profesional Bahasa Indonesia.\n"
                . "4. 'analysis.strengths': Tepat 3 poin kekuatan utama yang spesifik dan berbasis fakta dari isi CV.\n"
                . "5. 'analysis.improvements': 2 sampai 3 poin saran konkret dan konstruktif untuk memperkuat daya saing CV.\n"
                . "6. 'analysis.recommended_roles': 3 sampai 5 posisi magang atau pekerjaan pemula yang paling sesuai dengan profil kandidat.";

            if ($file) {
                $mime = (string) $file->getMimeType();
                $ext  = strtolower($file->getClientOriginalExtension());

                if ($ext === 'pdf' || str_contains($mime, 'pdf')) {
                    try {
                        $textToAnalyze = $this->gemini->extractCleanTextFromPdf($file->getRealPath());
                    } catch (\Throwable $pdfEx) {
                        Log::warning('Gagal mengekstrak teks PDF dengan PdfParser: ' . $pdfEx->getMessage());
                        return response()->json([
                            'message' => 'File PDF tidak dapat dibaca (mungkin terenkripsi atau rusak). Pastikan PDF tidak dikunci password dan berisi teks.',
                        ], 422);
                    }

                    if (mb_strlen($textToAnalyze) < 30) {
                        return response()->json([
                            'message' => 'Teks dari file PDF tidak dapat diekstrak atau terlalu pendek. Pastikan PDF berisi teks (bukan scan gambar).',
                        ], 422);
                    }
                } elseif ($ext === 'txt' || str_contains($mime, 'text')) {
                    $textToAnalyze = $this->gemini->cleanExtractedText((string) file_get_contents($file->getRealPath()));
                    if (mb_strlen($textToAnalyze) < 50) {
                        return response()->json([
                            'message' => 'Teks dari file CV terlalu pendek (minimal 50 karakter).',
                        ], 422);
                    }
                }
            } elseif (! empty($cvText)) {
                $textToAnalyze = $this->gemini->cleanExtractedText((string) $cvText);
                if (mb_strlen($textToAnalyze) < 50) {
                    return response()->json([
                        'message' => 'Teks CV (cv_text) minimal 50 karakter.',
                    ], 422);
                }
            }

            $json = null;
            try {
                $json = $this->gemini->analyzeCvText($textToAnalyze, self::EXTRACT_CV_SYSTEM, $instructionPrompt);
            } catch (\Throwable $e) {
                Log::warning('Gemini extract-cv gagal atau timeout: ' . $e->getMessage() . '. Menjalankan fallback lokal berbasis teks bersih.');
                $json = $this->gemini->fallbackExtractCvFromCleanText($textToAnalyze);
            }

            $rawSkills = $json['skills'] ?? [];
            if (! is_array($rawSkills)) {
                $rawSkills = [];
            }

            $skills = collect($rawSkills)
                ->map(fn ($s) => trim((string) $s))
                ->filter(fn ($s) => $s !== '')
                ->unique()
                ->values()
                ->all();

            $major = trim((string) ($json['major'] ?? ''));

            $rawAnalysis = $json['analysis'] ?? [];
            if (! is_array($rawAnalysis)) {
                $rawAnalysis = [];
            }

            $rawSummary          = $rawAnalysis['summary'] ?? ($json['summary'] ?? null);
            $rawStrengths        = $rawAnalysis['strengths'] ?? ($json['strengths'] ?? null);
            $rawImprovements     = $rawAnalysis['improvements'] ?? ($json['improvements'] ?? null);
            $rawRecommendedRoles = $rawAnalysis['recommended_roles'] ?? ($json['recommended_roles'] ?? null);

            $analysis = [
                'summary'           => trim((string) ($rawSummary ?? ($skills ? 'Kandidat memiliki keahlian di bidang ' . ($major ?: 'profesional') . ' dengan kompetensi utama: ' . implode(', ', array_slice($skills, 0, 3)) . '.' : 'Profil kandidat siap berkembang dengan keahlian yang relevan.'))),
                'strengths'         => is_array($rawStrengths) && ! empty($rawStrengths)
                    ? array_values(array_filter(array_map('trim', $rawStrengths)))
                    : [
                        'Memiliki keahlian nyata dalam ' . implode(' dan ', array_slice($skills, 0, 2)),
                        'Latar belakang keilmuan yang relevan di bidang ' . ($major ?: 'studinya'),
                        'Kesiapan belajar dan adaptasi tinggi di lingkungan kerja',
                    ],
                'improvements'      => is_array($rawImprovements) && ! empty($rawImprovements)
                    ? array_values(array_filter(array_map('trim', $rawImprovements)))
                    : [
                        'Tambahkan metrik kuantitatif pada pencapaian proyek dan pengalaman kerja.',
                        'Sertakan tautan portofolio atau bukti hasil karya untuk memvalidasi keahlian.',
                    ],
                'recommended_roles' => is_array($rawRecommendedRoles) && ! empty($rawRecommendedRoles)
                    ? array_values(array_filter(array_map('trim', $rawRecommendedRoles)))
                    : $this->gemini->getRecommendedRolesForMajor($major, $skills),
            ];

            $user = $request->user();
            if ($user) {
                $user->user_skills = $skills;

                if (! empty($major)) {
                    $user->major = $major;
                }

                $user->save();
            }

            return response()->json([
                'message'          => 'CV berhasil dianalisis',
                'user'             => $user ? $user->fresh() : null,
                'extracted_skills' => $skills,
                'skills'           => $skills,
                'major'            => $major,
                'analysis'         => $analysis,
            ], 200);

        } catch (\Illuminate\Validation\ValidationException $ve) {
            return response()->json([
                'message' => $ve->getMessage(),
                'errors'  => $ve->errors(),
            ], 422);
        } catch (\Throwable $e) {
            Log::warning('Gemini extract-cv exception: ' . $e->getMessage());

            try {
                $cleanFallbackText = $textToAnalyze;
                if ($cleanFallbackText === '') {
                    $file = $request->file('cv_file');
                    if ($file) {
                        $ext  = strtolower($file->getClientOriginalExtension());
                        $mime = (string) $file->getMimeType();
                        if ($ext === 'pdf' || str_contains($mime, 'pdf')) {
                            $cleanFallbackText = $this->gemini->extractCleanTextFromPdf($file->getRealPath());
                        } else {
                            $cleanFallbackText = $this->gemini->cleanExtractedText((string) file_get_contents($file->getRealPath()));
                        }
                    } else {
                        $cleanFallbackText = $this->gemini->cleanExtractedText((string) ($request->input('cv_text') ?? ''));
                    }
                }

                $fallback = $this->gemini->fallbackExtractCvFromCleanText($cleanFallbackText);

                $user = $request->user();
                if ($user) {
                    $user->user_skills = $fallback['skills'];
                    if (! empty($fallback['major'])) {
                        $user->major = $fallback['major'];
                    }
                    $user->save();
                }

                return response()->json([
                    'message'          => 'CV berhasil dianalisis',
                    'user'             => $user ? $user->fresh() : null,
                    'extracted_skills' => $fallback['skills'],
                    'skills'           => $fallback['skills'],
                    'major'            => $fallback['major'],
                    'analysis'         => $fallback['analysis'],
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

            // 4. Rekomendasi Magang & Peluang Diterima berdasarkan skill & jurusan user
            $jobRecommendations = $this->computeJobRecommendations($request->user(), $allJobs);

            return response()->json([
                'data' => [
                    'total_jobs'          => (int) $totalJobs,
                    'stipend_breakdown'   => $stipendBreakdown,
                    'location_breakdown'  => $locationBreakdown,
                    'top_skills'          => $topSkills,
                    'job_recommendations' => $jobRecommendations,
                ],
            ], 200);
        } catch (\Throwable $e) {
            Log::error('marketTrends error: ' . $e->getMessage());
            return response()->json([
                'data' => [
                    'total_jobs'          => 0,
                    'stipend_breakdown'   => [
                        'paid'   => 0,
                        'unpaid' => 0,
                    ],
                    'location_breakdown'  => [
                        'remote'        => 0,
                        'onsite_hybrid' => 0,
                        'onsite'        => 0,
                        'hybrid'        => 0,
                    ],
                    'top_skills'          => [],
                    'job_recommendations' => [],
                ],
                'error' => $e->getMessage(),
            ], 200);
        }
    }

    /**
     * FITUR REKOMENDASI MAGANG: GET /api/analytics/recommendations
     * Mengembalikan lowongan rekomendasi terbaik (minimal 6-8 posisi) dengan perhitungan match_percentage,
     * matched_skills, missing_skills, dan reason personal berbahasa Indonesia.
     */
    public function recommendations(Request $request): JsonResponse
    {
        @set_time_limit(120);

        try {
            $allJobs = $this->getAllActiveJobs();
            $recommendations = $this->computeJobRecommendations($request->user(), $allJobs);

            return response()->json([
                'data' => $recommendations,
            ], 200);
        } catch (\Throwable $e) {
            Log::error('recommendations error: ' . $e->getMessage());
            return response()->json([
                'data'  => [],
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
            if (CustomJob::where('is_active', true)->count() < 25) {
                CustomJobSeeder::seedJobs();
            }
        } catch (\Throwable $e) {
            // Abaikan jika database connection belum siap
        }

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
     * Hitung rekomendasi lowongan magang berdasarkan skills dan major user.
     * Mengembalikan 6-8 posisi dengan match_percentage (65%-96%), matched_skills, missing_skills, dan reason.
     */
    private function computeJobRecommendations(?User $user, Collection $allJobs): array
    {
        try {
            $userSkills = $user?->user_skills ?? [];
            if (! is_array($userSkills)) {
                $userSkills = [];
            }
            $userSkills = array_values(array_filter(array_map('trim', $userSkills)));
            $userMajor = trim((string) ($user?->major ?? ''));

            $scoredJobs = [];
            $commonSkillPool = [
                'Informatika/SI'      => ['Flutter', 'React', 'Python', 'SQL', 'Git', 'REST API', 'Docker', 'Machine Learning', 'Go', 'PHP', 'Tailwind CSS', 'Figma'],
                'DKV'                 => ['Figma', 'UI/UX Design', 'Design System', 'Adobe Illustrator', 'Photoshop', 'User Research', 'Wireframing', 'Prototyping'],
                'Manajemen/Pemasaran' => ['Digital Marketing', 'Social Media Strategy', 'Content Writing', 'SEO', 'Google Analytics', 'Market Research', 'Excel', 'Public Relations'],
                'Akuntansi/Keuangan'  => ['Financial Analysis', 'Excel Advanced', 'PSAK / IFRS', 'Perpajakan PPh', 'Audit', 'Rekonsiliasi Bank', 'SQL Data Finance'],
                'Teknik Elektro'      => ['Mikrokontroler ESP32', 'PLC Programming', 'C/C++', 'IoT MQTT', 'SCADA', 'Desain Skematik PCB', 'Rangkaian Listrik'],
                'Lainnya'             => ['Communication', 'Microsoft Excel', 'Project Management', 'Problem Solving', 'Data Analysis', 'Team Collaboration'],
            ];

            foreach ($allJobs as $job) {
                $title    = (string) ($job['job_title'] ?? '');
                $req      = (string) ($job['job_requirements'] ?? '');
                $company  = (string) ($job['company_name'] ?? '');
                $category = (string) ($job['major_category'] ?? 'Lainnya');
                $fullText = mb_strtolower($title . ' ' . $req . ' ' . $company);

                // 1. Matched skills
                $matched = [];
                foreach ($userSkills as $skill) {
                    $sLower = mb_strtolower(trim($skill));
                    if ($sLower !== '' && mb_strlen($sLower) >= 2) {
                        if (str_contains($fullText, $sLower)) {
                            $matched[] = $skill;
                        }
                    }
                }
                $matched = array_values(array_unique($matched));

                // 2. Kesesuaian Jurusan
                $majorScore = 0;
                if ($userMajor !== '') {
                    $uMajorLower = mb_strtolower($userMajor);
                    $catLower    = mb_strtolower($category);
                    if (str_contains($catLower, 'informatika') && (str_contains($uMajorLower, 'informatika') || str_contains($uMajorLower, 'komputer') || str_contains($uMajorLower, 'sistem informasi') || str_contains($uMajorLower, 'software') || str_contains($uMajorLower, 'data'))) {
                        $majorScore = 25;
                    } elseif (str_contains($catLower, 'dkv') && (str_contains($uMajorLower, 'desain') || str_contains($uMajorLower, 'dkv') || str_contains($uMajorLower, 'visual') || str_contains($uMajorLower, 'multimedia'))) {
                        $majorScore = 25;
                    } elseif (str_contains($catLower, 'manajemen') && (str_contains($uMajorLower, 'manajemen') || str_contains($uMajorLower, 'pemasaran') || str_contains($uMajorLower, 'marketing') || str_contains($uMajorLower, 'bisnis') || str_contains($uMajorLower, 'komunikasi'))) {
                        $majorScore = 25;
                    } elseif (str_contains($catLower, 'akuntansi') && (str_contains($uMajorLower, 'akuntansi') || str_contains($uMajorLower, 'keuangan') || str_contains($uMajorLower, 'finance') || str_contains($uMajorLower, 'perbankan'))) {
                        $majorScore = 25;
                    } elseif (str_contains($catLower, 'elektro') && (str_contains($uMajorLower, 'elektro') || str_contains($uMajorLower, 'mekatronika') || str_contains($uMajorLower, 'otomasi'))) {
                        $majorScore = 25;
                    } elseif (str_contains($fullText, $uMajorLower)) {
                        $majorScore = 15;
                    }
                }

                // 3. Persentase kecocokan (65% - 96%)
                $matchCount = count($matched);
                if ($matchCount > 0) {
                    $base = 66 + min(18, $matchCount * 6) + ($majorScore > 0 ? 8 : 0);
                } elseif ($majorScore > 0) {
                    $base = 65 + ($majorScore > 15 ? 8 : 4);
                } else {
                    $base = 60;
                }

                // Variasi deterministik berdasarkan judul agar angka natural (misal 94%, 91%, 88%, dll.)
                $deterministicJitter = (abs(crc32($title . $company)) % 5) - 2;
                $finalPercentage = (int) max(65, min(96, $base + $deterministicJitter));

                // 4. Missing skills yang disarankan
                $pool = $commonSkillPool[$category] ?? $commonSkillPool['Lainnya'];
                $missing = [];
                foreach ($pool as $candidateSkill) {
                    $cLower = mb_strtolower($candidateSkill);
                    $alreadyHas = false;
                    foreach ($userSkills as $us) {
                        if (mb_strtolower($us) === $cLower) {
                            $alreadyHas = true;
                            break;
                        }
                    }
                    if (! $alreadyHas && str_contains($fullText, $cLower)) {
                        $missing[] = $candidateSkill;
                    }
                }
                if (empty($missing)) {
                    foreach ($pool as $candidateSkill) {
                        $cLower = mb_strtolower($candidateSkill);
                        $alreadyHas = false;
                        foreach ($userSkills as $us) {
                            if (mb_strtolower($us) === $cLower) {
                                $alreadyHas = true;
                                break;
                            }
                        }
                        if (! $alreadyHas) {
                            $missing[] = $candidateSkill;
                            if (count($missing) >= 2) break;
                        }
                    }
                }
                $missing = array_slice(array_values(array_unique($missing)), 0, 2);

                $scoredJobs[] = [
                    'id'               => $job['id'],
                    'job_title'        => $title,
                    'company_name'     => $company,
                    'location'         => $job['location'] ?? 'Remote',
                    'major_category'   => $category,
                    'stipend_type'     => $job['stipend_type'] ?? 'paid',
                    'salary_range'     => $job['salary_range'],
                    'job_requirements' => Str::limit($req, 300),
                    'job_url'          => $job['job_url'] ?? null,
                    'match_percentage' => $finalPercentage,
                    'matched_skills'   => $matched,
                    'missing_skills'   => $missing,
                    'raw_score'        => ($matchCount * 12) + $majorScore + $finalPercentage,
                ];
            }

            // Urutkan berdasarkan skor tertinggi
            usort($scoredJobs, fn ($a, $b) => $b['raw_score'] <=> $a['raw_score']);

            // Ambil 6-8 rekomendasi teratas
            $topJobs = array_slice($scoredJobs, 0, 8);

            // Perkaya dengan alasan personal (Gemini AI + Fallback)
            return $this->enrichRecommendationsWithReasons($topJobs, $userSkills, $userMajor);
        } catch (\Throwable $e) {
            Log::warning('computeJobRecommendations error: ' . $e->getMessage());
            return [];
        }
    }

    /**
     * Memperkaya rekomendasi dengan penjelasan alasan personal (reason) berbahasa Indonesia.
     */
    private function enrichRecommendationsWithReasons(array $jobs, array $userSkills, string $userMajor): array
    {
        // 1. Alasan default berkualitas tinggi (fallback lokal instan)
        $fallbackEnriched = [];
        foreach ($jobs as $job) {
            $pct        = $job['match_percentage'];
            $title      = $job['job_title'];
            $company    = $job['company_name'];
            $matched    = $job['matched_skills'];
            $missing    = $job['missing_skills'];
            $missingStr = ! empty($missing) ? implode(' dan ', $missing) : 'portofolio proyek praktis';

            if (! empty($matched)) {
                $matchedStr = implode(', ', array_slice($matched, 0, 3));
                $reason = "Profil Anda sangat sesuai ({$pct}% peluang) untuk posisi {$title} di {$company} karena Anda telah menguasai {$matchedStr} yang menjadi kebutuhan kunci posisi ini. Anda dapat memperkuat daya saing lamaran dengan menambahkan pemahaman pada {$missingStr}.";
            } elseif (! empty($userMajor)) {
                $reason = "Posisi {$title} di {$company} memiliki korelasi tinggi dengan latar belakang bidang studi {$userMajor} Anda ({$pct}% peluang). Mempelajari kemampuan spesifik seperti {$missingStr} akan melipatgandakan peluang Anda lolos seleksi berkas dan interview.";
            } else {
                $reason = "Kandidat memiliki potensi kompetensi yang relevan ({$pct}% peluang) untuk posisi {$title} di {$company}. Memperkuat keahlian pada {$missingStr} akan memberikan nilai tambah nyata bagi tim kerja.";
            }

            $job['reason'] = $reason;
            unset($job['raw_score']);
            $fallbackEnriched[] = $job;
        }

        // 2. Coba minta Gemini menyusun narasi yang lebih dinamis jika API aktif
        try {
            $promptData = [];
            foreach ($jobs as $idx => $j) {
                $promptData[] = [
                    'index'          => $idx,
                    'job_title'      => $j['job_title'],
                    'company_name'   => $j['company_name'],
                    'matched_skills' => $j['matched_skills'],
                    'missing_skills' => $j['missing_skills'],
                    'percentage'     => $j['match_percentage'],
                ];
            }

            $prompt = "Berikut adalah daftar kesesuaian lowongan magang untuk user (Jurusan: {$userMajor}, Skill user: " . implode(', ', array_slice($userSkills, 0, 10)) . "):\n"
                . json_encode($promptData, JSON_UNESCAPED_UNICODE) . "\n\n"
                . "Buatkan alasan personal rekomendasi berbahasa Indonesia yang meyakinkan (2-3 kalimat per lowongan). Sebutkan secara spesifik skill yang sudah dimiliki user yang cocok, serta 1-2 skill tambahan untuk memperkuat peluang diterima.\n"
                . "Kembalikan HANYA JSON array dengan struktur: [{\"index\": 0, \"reason\": \"...\"}, ...]";

            $res = $this->callGeminiDirectJson(
                'Kamu adalah Senior Career Coach dan HR Specialist profesional.',
                $prompt
            );

            if (is_array($res)) {
                $items = isset($res['data']) && is_array($res['data']) ? $res['data'] : $res;
                foreach ($items as $item) {
                    if (isset($item['index'], $item['reason']) && isset($fallbackEnriched[$item['index']])) {
                        $reasonText = trim((string) $item['reason']);
                        if (mb_strlen($reasonText) > 20) {
                            $fallbackEnriched[$item['index']]['reason'] = $reasonText;
                        }
                    }
                }
            }
        } catch (\Throwable $e) {
            // Log & gunakan fallback lokal tanpa mengganggu respons
            Log::info('Gemini recommendations reason skipped/fallback: ' . $e->getMessage());
        }

        return $fallbackEnriched;
    }

    /**
     * Kamus pola regex keahlian teknis/tools industri (berbagi dari GeminiService).
     */
    private function getSkillPatterns(): array
    {
        return $this->gemini->getUniversalSkillDictionary();
    }

    /**
     * Fallback analisis kesenjangan skill lokal jika Gemini API timeout atau gagal.
     */
    private function fallbackSkillGap(array $data, array $userSkills): array
    {
        $allPatterns = $this->gemini->getUniversalSkillDictionary();
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
     * Panggilan ke GeminiService dengan parameter string tunggal.
     */
    private function callGeminiDirectJson(string $system, string $prompt): array
    {
        return $this->gemini->jsonWithParts($system, [['text' => $prompt]], 0.2, 60);
    }
}
