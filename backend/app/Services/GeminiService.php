<?php

namespace App\Services;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Smalot\PdfParser\Parser;

/**
 * Klien REST untuk Google Gemini API (generateContent),
 * disertai ekstraktor teks bersih PDF (\Smalot\PdfParser\Parser) dan fallback analisis CV lokal.
 * Konfigurasi lewat .env: GEMINI_API_KEY dan (opsional) GEMINI_MODEL.
 */
class GeminiService
{
    private const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/';

    /** Jawaban teks bebas. */
    public function text(string $system, string $prompt, float $temperature = 0.7): string
    {
        return $this->call($system, $prompt, ['temperature' => $temperature]);
    }

    /** Jawaban terstruktur (JSON) -> array. */
    public function json(string $system, string $prompt, float $temperature = 0.4): array
    {
        return $this->jsonWithParts($system, [['text' => $prompt]], $temperature);
    }

    /** Jawaban terstruktur (JSON) dengan input parts (teks atau inlineData PDF) -> array. */
    public function jsonWithParts(string $system, array $parts, float $temperature = 0.3, int $timeout = 60): array
    {
        $raw = $this->callWithParts($system, $parts, [
            'temperature'      => $temperature,
            'responseMimeType' => 'application/json',
        ], $timeout);

        return $this->parseJson($raw);
    }

    private function call(string $system, string $prompt, array $config): string
    {
        return $this->callWithParts($system, [['text' => $prompt]], $config);
    }

    public function callWithParts(string $system, array $parts, array $config, int $timeout = 60): string
    {
        $key = (string) env('GEMINI_API_KEY', '');
        if ($key === '') {
            throw new GeminiException('GEMINI_API_KEY belum diisi di file .env backend.');
        }

        $model = (string) env('GEMINI_MODEL', 'gemini-2.5-flash');
        if ($model === '') {
            $model = 'gemini-2.5-flash';
        }

        $payload = [
            'systemInstruction' => ['parts' => [['text' => $system]]],
            'contents'          => [['role' => 'user', 'parts' => $parts]],
            'generationConfig'  => $config + ['maxOutputTokens' => 8192],
        ];

        $response = null;
        $activeModel = $model;

        for ($attempt = 1; $attempt <= 2; $attempt++) {
            try {
                $response = Http::withoutVerifying()
                    ->withOptions([
                        'curl' => [
                            CURLOPT_IPRESOLVE => CURL_IPRESOLVE_V4,
                        ],
                    ])
                    ->timeout($timeout)
                    ->withHeaders(['x-goog-api-key' => $key])
                    ->acceptJson()
                    ->asJson()
                    ->post(self::ENDPOINT . $activeModel . ':generateContent', $payload);
            } catch (\Throwable $e) {
                Log::warning('Gemini koneksi gagal: ' . $e->getMessage());
                throw new GeminiException('Tidak dapat menghubungi Gemini. Periksa koneksi internet laptop Anda.');
            }

            // Jika model lama (mis. gemini-2.5-flash) mengembalikan 404, coba fallback ke gemini-3.8-flash sekali.
            if ($response->status() === 404 && $activeModel !== 'gemini-3.8-flash' && $attempt === 1) {
                Log::warning("Gemini model '{$activeModel}' mengembalikan 404, mencoba fallback ke 'gemini-3.8-flash'.");
                $activeModel = 'gemini-3.8-flash';
                continue;
            }

            // 503 = server sibuk, coba sekali lagi.
            if ($response->status() !== 503 || $attempt === 2) {
                break;
            }
            usleep(1500000);
        }

        if (! $response->successful()) {
            throw $this->httpError($response, $activeModel);
        }

        $parts = $response->json('candidates.0.content.parts', []);
        $text  = collect($parts)
            ->reject(fn ($p) => ! empty($p['thought']))
            ->pluck('text')
            ->implode('');

        if (trim($text) === '') {
            $reason = $response->json('candidates.0.finishReason')
                ?? $response->json('promptFeedback.blockReason');
            throw new GeminiException(
                'AI tidak mengembalikan jawaban' . ($reason ? " ({$reason})" : '') . '. Coba lagi.'
            );
        }

        return trim($text);
    }

    private function httpError(Response $response, string $model): GeminiException
    {
        $status  = $response->status();
        $message = (string) $response->json('error.message', '');
        Log::warning("Gemini HTTP {$status}: {$message}");

        if ($status === 429) {
            return new GeminiException('Kuota Gemini sedang habis atau terlalu banyak permintaan. Tunggu sekitar satu menit lalu coba lagi.');
        }
        if ($status === 404) {
            return new GeminiException("Model '{$model}' tidak ditemukan untuk akun Anda. Ganti GEMINI_MODEL di .env dengan model yang tersedia di Google AI Studio.");
        }
        if ($status === 400 && stripos($message, 'api key') !== false) {
            return new GeminiException('GEMINI_API_KEY tidak valid. Periksa kembali di file .env.');
        }
        if ($status === 401 || $status === 403) {
            return new GeminiException('API key Gemini ditolak (tidak valid atau tidak punya izin).');
        }
        if ($status === 503) {
            return new GeminiException('Server Gemini sedang sibuk. Coba lagi beberapa saat.');
        }

        return new GeminiException('Gemini error (' . $status . '): ' . mb_substr($message, 0, 160));
    }

    private function parseJson(string $raw): array
    {
        $clean = trim(preg_replace('/^```(?:json)?\s*|\s*```$/i', '', trim($raw)));
        $data  = json_decode($clean, true);

        if (! is_array($data)) {
            $start = strpos($clean, '{');
            $end   = strrpos($clean, '}');
            if ($start !== false && $end !== false && $end > $start) {
                $data = json_decode(substr($clean, $start, $end - $start + 1), true);
            }
        }

        if (! is_array($data)) {
            throw new GeminiException('Respons AI tidak valid. Coba lagi.');
        }

        return $data;
    }

    /**
     * Ekstrak seluruh teks asli dari file PDF menggunakan \Smalot\PdfParser\Parser
     * dan bersihkan dari karakter non-UTF8 serta whitespace berlebih.
     */
    public function extractCleanTextFromPdf(string $filePath): string
    {
        if ($filePath === '' || ! is_file($filePath)) {
            return '';
        }

        $parser = new Parser();
        $pdf    = $parser->parseFile($filePath);
        $raw    = (string) $pdf->getText();

        return $this->cleanExtractedText($raw);
    }

    /**
     * Bersihkan string teks hasil ekstraksi CV dari karakter non-UTF8, control character,
     * dan spasi/baris baru berlebih. Menolak input biner mentah PDF.
     */
    public function cleanExtractedText(string $text): string
    {
        if ($text === '' || $this->isRawPdfBinary($text)) {
            return '';
        }

        $utf8 = @iconv('UTF-8', 'UTF-8//IGNORE', $text);
        if ($utf8 === false) {
            $utf8 = mb_convert_encoding($text, 'UTF-8', 'UTF-8');
        }

        // Hapus karakter kontrol ASCII selain \t, \n, \r
        $clean = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', ' ', $utf8);
        $clean = str_replace(["\r\n", "\r"], "\n", (string) $clean);
        $clean = preg_replace('/[ \t\x{00A0}]+/u', ' ', $clean);
        $clean = preg_replace('/ *\n */u', "\n", (string) $clean);
        $clean = preg_replace("/\n{3,}/", "\n\n", (string) $clean);

        $clean = trim((string) $clean);

        if ($this->isRawPdfBinary($clean)) {
            return '';
        }

        return $clean;
    }

    /**
     * Kirim teks bersih CV ke Gemini API sebagai teks biasa (parts: [{ text: ... }]),
     * bukan inlineData biner PDF, agar hemat kuota token dan cepat.
     */
    public function analyzeCvText(string $cleanText, string $system, string $instructionPrompt): array
    {
        $clean = $this->cleanExtractedText($cleanText);
        if ($clean === '') {
            throw new GeminiException('Teks CV kosong atau bukan teks bersih yang valid.');
        }

        $parts = [
            [
                'text' => "Berikut adalah isi teks CV kandidat:\n<cv>\n"
                    . Str::limit($clean, 12000, '') . "\n</cv>\n\n"
                    . $instructionPrompt,
            ],
        ];

        return $this->jsonWithParts($system, $parts, 0.2, 60);
    }

    /**
     * Fallback analisis CV lokal berbasis teks bersih (tanpa pernah memindai data biner mentah).
     * Menggunakan word boundary \b yang akurat untuk jurusan dan keahlian lintas bidang.
     */
    public function fallbackExtractCvFromCleanText(string $cleanText): array
    {
        if ($this->isRawPdfBinary($cleanText)) {
            throw new \InvalidArgumentException('Input biner PDF mentah ditolak oleh fallback lokal.');
        }

        $clean = $this->cleanExtractedText($cleanText);
        if ($clean === '') {
            throw new \InvalidArgumentException('Teks bersih CV kosong, fallback lokal tidak dapat dijalankan.');
        }

        $extractedSkills = [];

        // 1. Ekstraksi dinamis dari bagian bertajuk "Skills / Keahlian / Competencies / Tools"
        $sectionPattern = '/(?:^|\n)\s*(?:###?\s*)?(?:SKILLS?|KEAHLIAN|COMPETENC(?:IES|E)|KOMPETENSI|TECHNICAL\s+SKILLS?|KEAHLIAN\s+KHUSUS|KEAHLIAN\s+DAN\s+KEMAMPUAN|TOOLS?\s*(?:&|\+|AND)?\s*TECHNOLOG(?:IES|Y)?|KEAHLIAN\s+TEKNIS|KEMAMPUAN)\s*[:\n](.*?)(?=\n\s*(?:###?\s*)?(?:EXPERIENCE|PENGALAMAN|EDUCATION|PENDIDIKAN|PROJECTS?|PROYEK|ORGANIZAT?ION|ORGANISASI|CERTIFICA(?:TION|T)S?|SERTIFIKASI|AWARDS?|PENGHARGAAN|LANGUAGES?|BAHASA|CONTACT|KONTAK|PROFIL|SUMMARY)\b|$)/is';
        if (preg_match($sectionPattern, $clean, $secMatches)) {
            $sectionContent = $secMatches[1];
            $items = preg_split('/[•*|\n;,\t✓▪▫–—]+/u', $sectionContent);
            foreach ($items as $item) {
                $cleaned = trim((string) preg_replace('/^[\s\d\-.)]+/', '', $item));
                $len = mb_strlen($cleaned);
                if ($len >= 2 && $len <= 45 && ! preg_match('/^(and|dan|or|atau|etc|dll|tahun|years|level|proficient|basic|intermediate|advanced)$/i', $cleaned)) {
                    $extractedSkills[$cleaned] = true;
                }
            }
        }

        // 2. Pencocokan kamus lintas bidang menggunakan word boundary (\b)
        $patterns = $this->getUniversalSkillDictionary();
        $matchedDict = [];
        foreach ($patterns as $skill => $regex) {
            if (@preg_match($regex, $clean, $m, PREG_OFFSET_CAPTURE)) {
                $matchedDict[$skill] = $m[0][1];
            }
        }
        asort($matchedDict);

        foreach (array_keys($matchedDict) as $sk) {
            $extractedSkills[$sk] = true;
        }

        $finalSkills = array_keys($extractedSkills);
        if (empty($finalSkills)) {
            $finalSkills = [
                'Communication',
                'Problem Solving',
                'Teamwork',
                'Project Management',
                'Time Management',
                'Critical Thinking',
            ];
        }

        // 3. Deteksi jurusan lintas bidang (prioritaskan bagian Education/Pendidikan terlebih dahulu)
        $detectedMajor = $this->detectMajorFromCleanText($clean);

        // 4. Bangun objek analysis lengkap
        $topSkillList = array_slice($finalSkills, 0, 3);
        $summary = "Kandidat berlatar belakang {$detectedMajor} dengan kompetensi utama pada "
            . implode(', ', $topSkillList)
            . '. Memiliki bekal keterampilan terstruktur serta kesiapan untuk berkontribusi secara produktif dalam program magang dan kerja profesional.';

        $strengths = [
            'Memiliki penguasaan nyata dalam ' . implode(' dan ', array_slice($finalSkills, 0, 2)) . ' yang relevan dengan tuntutan industri.',
            'Latar belakang keilmuan ' . $detectedMajor . ' yang solid didukung keterampilan pemecahan masalah secara terstruktur.',
            'Kemampuan komunikasi, adaptabilitas, serta kerja sama tim yang baik untuk lingkungan kerja yang dinamis.',
        ];

        $improvements = [
            'Sertakan pencapaian berbasis data kuantitatif (misalnya persentase hasil, efisiensi waktu, atau skala proyek) pada riwayat pengalaman.',
            'Lengkapi portofolio kerja atau tautan proyek nyata untuk memvalidasi penerapan keahlian utama.',
            'Perjelas peran spesifik dan tanggung jawab utama pada setiap pengalaman organisasi atau magang sebelumnya.',
        ];

        return [
            'skills'   => $finalSkills,
            'major'    => $detectedMajor,
            'analysis' => [
                'summary'           => $summary,
                'strengths'         => $strengths,
                'improvements'      => $improvements,
                'recommended_roles' => $this->getRecommendedRolesForMajor($detectedMajor, $finalSkills),
            ],
        ];
    }

    /**
     * Deteksi jurusan dari teks bersih CV dengan word boundary \b.
     * Memprioritaskan bagian Education/Pendidikan terlebih dahulu agar tidak salah tangkap kata umum.
     */
    private function detectMajorFromCleanText(string $clean): string
    {
        $majorPatterns = [
            // Teknologi & Komputer
            'Sistem Informasi'          => '/\b(sistem\s+informasi|information\s+systems?)\b/i',
            'Teknik Informatika'        => '/\b(teknik\s+informatika|informatics|computer\s+science|ilmu\s+komputer)\b/i',
            'Sains Data'                => '/\b(sains\s+data|data\s+science)\b/i',
            'Teknologi Informasi'       => '/\b(teknologi\s+informasi|information\s+technology)\b/i',
            'Teknik Komputer'           => '/\b(teknik\s+komputer|computer\s+engineering)\b/i',
            'Rekayasa Perangkat Lunak'  => '/\b(rpl|rekayasa\s+perangkat\s+lunak|software\s+engineering)\b/i',

            // Bisnis, Manajemen & Keuangan
            'Manajemen Bisnis'          => '/\b(manajemen\s+bisnis|business\s+management)\b/i',
            'Manajemen'                 => '/\b(manajemen|management)\b/i',
            'Akuntansi'                 => '/\b(akuntansi|accounting)\b/i',
            'Ilmu Ekonomi'              => '/\b(ilmu\s+ekonomi|economics|ekonomi\s+pembangunan)\b/i',
            'Bisnis Digital'            => '/\b(bisnis\s+digital|digital\s+business)\b/i',
            'Keuangan & Perbankan'      => '/\b(keuangan|banking|perbankan|finance)\b/i',

            // Komunikasi, Desain & Media
            'Ilmu Komunikasi'           => '/\b(ilmu\s+komunikasi|communication\s+science|komunikasi)\b/i',
            'Desain Komunikasi Visual'  => '/\b(dkv|desain\s+komunikasi\s+visual|visual\s+communication\s+design|desain\s+grafis)\b/i',
            'Hubungan Internasional'    => '/\b(hubungan\s+internasional|international\s+relations)\b/i',
            'Hubungan Masyarakat'       => '/\b(hubungan\s+masyarakat|public\s+relations|humas)\b/i',

            // Teknik (Engineering)
            'Teknik Elektro'            => '/\b(teknik\s+elektro|electrical\s+engineering)\b/i',
            'Teknik Mesin'              => '/\b(teknik\s+mesin|mechanical\s+engineering)\b/i',
            'Teknik Sipil'              => '/\b(teknik\s+sipil|civil\s+engineering)\b/i',
            'Teknik Industri'           => '/\b(teknik\s+industri|industrial\s+engineering)\b/i',
            'Arsitektur'                => '/\b(arsitektur|architecture)\b/i',

            // Hukum & Sosial
            'Ilmu Hukum'                => '/\b(ilmu\s+hukum|sarjana\s+hukum|fakultas\s+hukum|bachelor\s+of\s+laws?|legal\s+studies|hukum)\b/i',
            'Psikologi'                 => '/\b(psikologi|psychology)\b/i',
            'Administrasi Bisnis'       => '/\b(administrasi\s+bisnis|business\s+administration)\b/i',
            'Administrasi Publik'       => '/\b(administrasi\s+publik|public\s+administration)\b/i',

            // Kesehatan & Medis
            'Farmasi'                   => '/\b(farmasi|pharmacy)\b/i',
            'Keperawatan'               => '/\b(keperawatan|nursing)\b/i',
            'Kesehatan Masyarakat'      => '/\b(kesehatan\s+masyarakat|public\s+health)\b/i',
            'Kedokteran'                => '/\b(kedokteran|medical\s+doctor)\b/i',
            'Gizi'                      => '/\b(ilmu\s+gizi|nutrition)\b/i',

            // Sains & Pendidikan
            'Statistika'                => '/\b(statistika|statistics)\b/i',
            'Matematika'                => '/\b(matematika|mathematics)\b/i',
            'Sastra Inggris'            => '/\b(sastra\s+inggris|english\s+literature)\b/i',
        ];

        $eduPattern = '/(?:^|\n)\s*(?:###?\s*)?(?:EDUCATION|PENDIDIKAN|ACADEMIC\s+BACKGROUND|RIWAYAT\s+PENDIDIKAN)\b[:\s]*(.*?)(?=\n\s*(?:###?\s*)?(?:EXPERIENCE|PENGALAMAN|SKILLS?|KEAHLIAN|PROJECTS?|PROYEK|ORGANIZAT?ION|ORGANISASI|CERTIFICA(?:TION|T)S?|SERTIFIKASI|AWARDS?|PENGHARGAAN|LANGUAGES?|BAHASA)\b|$)/is';
        if (preg_match($eduPattern, $clean, $eduMatch)) {
            $eduSection = $eduMatch[1];
            foreach ($majorPatterns as $majorName => $mRegex) {
                if (@preg_match($mRegex, $eduSection)) {
                    return $majorName;
                }
            }
        }

        foreach ($majorPatterns as $majorName => $mRegex) {
            if (@preg_match($mRegex, $clean)) {
                return $majorName;
            }
        }

        return 'Bidang Multidisiplin';
    }

    private function isRawPdfBinary(string $text): bool
    {
        if (str_contains($text, "\0")) {
            return true;
        }
        $trimmed = ltrim($text);
        if (str_starts_with($trimmed, '%PDF-')) {
            return true;
        }
        return preg_match('/\b(endobj|endstream|xref|startxref)\b/', substr($trimmed, 0, 4096)) === 1
            && preg_match('/\/Type\s*\/(?:Page|Catalog|Font)\b/', substr($trimmed, 0, 4096)) === 1;
    }

    /**
     * Memetakan rekomendasi peran magang/pekerjaan yang paling cocok berdasarkan jurusan dan keahlian.
     */
    public function getRecommendedRolesForMajor(string $major, array $skills): array
    {
        $majorLower = mb_strtolower($major);
        $skillsText = mb_strtolower(implode(' ', $skills));

        if (str_contains($majorLower, 'sistem informasi') || str_contains($majorLower, 'information system')) {
            if (str_contains($skillsText, 'flutter') || str_contains($skillsText, 'react') || str_contains($skillsText, 'laravel')) {
                return ['Fullstack Developer Intern', 'System Analyst Intern', 'Product & Business Analyst Intern', 'Software Engineer Intern'];
            }
            return ['System Analyst Intern', 'Business Analyst Intern', 'IT Project Coordinator Intern', 'Data & ERP Analyst Intern'];
        }

        if (str_contains($majorLower, 'informatik') || str_contains($majorLower, 'komputer') || str_contains($majorLower, 'software') || str_contains($majorLower, 'rpl') || str_contains($majorLower, 'teknologi informasi')) {
            if (str_contains($skillsText, 'flutter') || str_contains($skillsText, 'android') || str_contains($skillsText, 'swift')) {
                return ['Mobile App Developer Intern', 'Junior Flutter Developer', 'Frontend Mobile Engineer', 'QA Tester Intern'];
            }
            if (str_contains($skillsText, 'react') || str_contains($skillsText, 'frontend') || str_contains($skillsText, 'vue') || str_contains($skillsText, 'web')) {
                return ['Frontend Web Developer Intern', 'UI Engineer Intern', 'Junior Web Developer', 'Fullstack Intern'];
            }
            return ['Software Engineer Intern', 'Backend Developer Intern', 'Fullstack Developer Intern', 'IT Support / QA Intern'];
        }

        if (str_contains($majorLower, 'data') || (str_contains($skillsText, 'python') && str_contains($skillsText, 'data')) || str_contains($skillsText, 'machine learning')) {
            return ['Data Analyst Intern', 'Junior Data Scientist', 'Business Intelligence Intern', 'AI / ML Engineer Intern'];
        }

        if (str_contains($majorLower, 'akuntansi') || str_contains($majorLower, 'keuangan') || str_contains($skillsText, 'accounting') || str_contains($skillsText, 'pajak') || str_contains($skillsText, 'finance')) {
            return ['Finance & Accounting Intern', 'Tax Staff Assistant', 'Junior Auditor Intern', 'Financial Analyst Intern'];
        }

        if (str_contains($majorLower, 'manajemen') || str_contains($majorLower, 'bisnis') || str_contains($majorLower, 'ekonomi')) {
            return ['Business Development Intern', 'Project Management Intern', 'Operations Intern', 'Management Trainee Intern'];
        }

        if (str_contains($majorLower, 'komunikasi') || str_contains($majorLower, 'marketing') || str_contains($skillsText, 'social media') || str_contains($skillsText, 'seo') || str_contains($skillsText, 'content')) {
            return ['Digital Marketing Intern', 'Social Media Specialist', 'Public Relations Intern', 'Content Strategist Intern'];
        }

        if (str_contains($majorLower, 'desain') || str_contains($majorLower, 'dkv') || str_contains($skillsText, 'figma') || str_contains($skillsText, 'photoshop') || str_contains($skillsText, 'ui / ux')) {
            return ['UI/UX Designer Intern', 'Graphic Designer Intern', 'Creative Media Associate', 'Visual Designer Intern'];
        }

        if (str_contains($majorLower, 'hukum') || str_contains($skillsText, 'legal') || str_contains($skillsText, 'contract')) {
            return ['Legal Intern', 'Corporate Legal Assistant', 'Compliance Associate', 'Legal Research Assistant'];
        }

        if (str_contains($majorLower, 'elektro') || str_contains($majorLower, 'mesin') || str_contains($majorLower, 'sipil') || str_contains($majorLower, 'industri') || str_contains($majorLower, 'teknik')) {
            return ['Engineering Intern', 'Project Engineer Assistant', 'CAD / Drafter Assistant', 'Maintenance & Operations Intern'];
        }

        if (str_contains($majorLower, 'kesehatan') || str_contains($majorLower, 'farmasi') || str_contains($majorLower, 'perawat') || str_contains($majorLower, 'gizi')) {
            return ['Clinical Healthcare Intern', 'Pharmacy Assistant', 'Health Operations Intern', 'Medical Research Associate'];
        }

        return ['Project Management Intern', 'Business Development Associate', 'Operations Assistant', 'Research Analyst Intern'];
    }

    /**
     * Kamus lengkap keahlian universal lintas bidang dengan word boundary \b.
     */
    public function getUniversalSkillDictionary(): array
    {
        return [
            // 1. TEKNOLOGI, IT & SOFTWARE ENGINEERING
            'Python'                      => '/\bpython\b/i',
            'JavaScript'                  => '/\b(javascript|js)\b/i',
            'TypeScript'                  => '/\b(typescript|ts)\b/i',
            'PHP'                         => '/\bphp\b/i',
            'Laravel'                     => '/\blaravel\b/i',
            'CodeIgniter'                 => '/\bcodeigniter\b/i',
            'Java'                        => '/\bjava\b(?!\s*script)/i',
            'Kotlin'                      => '/\bkotlin\b/i',
            'Swift'                       => '/\bswift\b/i',
            'Flutter'                     => '/\bflutter\b/i',
            'Dart'                        => '/\bdart\b/i',
            'React'                       => '/\breact(\.js)?\b(?!\s*native)/i',
            'React Native'                => '/\breact[\s\-]native\b/i',
            'Vue.js'                      => '/\bvue(\.js)?\b/i',
            'Node.js'                     => '/\bnode(\.js)?\b/i',
            'Express.js'                  => '/\bexpress(\.js)?\b/i',
            'Next.js'                     => '/\bnext(\.js)?\b/i',
            'NestJS'                      => '/\bnest(\.js)?\b/i',
            'Spring Boot'                 => '/\bspring(\s*boot)?\b/i',
            'Django'                      => '/\bdjango\b/i',
            'FastAPI'                     => '/\bfastapi\b/i',
            'Flask'                       => '/\bflask\b/i',
            'Go / Golang'                 => '/\b(golang|go\s+language)\b/i',
            'C++'                         => '/\bc\+\+(?=\s|$|[,;.)])/i',
            'C#'                          => '/\b(c#|c\s*sharp)\b/i',
            'HTML / CSS'                  => '/\b(html5?|css3?)\b/i',
            'Tailwind CSS'                => '/\btailwind(\s*css)?\b/i',
            'Bootstrap'                   => '/\bbootstrap\b/i',
            'Git'                         => '/\bgit(hub|lab)?\b/i',
            'Docker'                      => '/\bdocker\b/i',
            'Kubernetes'                  => '/\b(kubernetes|k8s)\b/i',
            'Linux'                       => '/\blinux\b/i',
            'REST API'                    => '/\brest(ful)?\s*api\b/i',
            'GraphQL'                     => '/\bgraphql\b/i',
            'MySQL'                       => '/\bmysql\b/i',
            'PostgreSQL'                  => '/\bpostgres(ql)?\b/i',
            'MongoDB'                     => '/\bmongo(db)?\b/i',
            'Redis'                       => '/\bredis\b/i',
            'Firebase'                    => '/\bfirebase\b/i',
            'AWS'                         => '/\b(aws|amazon\s+web\s+services)\b/i',
            'GCP'                         => '/\b(gcp|google\s+cloud)\b/i',
            'Azure'                       => '/\bazure\b/i',
            'Cyber Security'              => '/\b(cyber\s*security|keamanan\s*siber)\b/i',
            'QA Testing'                  => '/\b(qa|quality\s+assurance|software\s+testing)\b/i',
            'CI / CD'                     => '/\bci[\/\s\-]?cd\b/i',

            // 2. DATA SCIENCE & AI
            'Data Analysis'               => '/\bdata\s+analy(sis|st|tics)\b/i',
            'Data Science'                => '/\bdata[\s\-]science\b/i',
            'Machine Learning'            => '/\b(machine[\s\-]learning|ml)\b/i',
            'Deep Learning'               => '/\bdeep[\s\-]learning\b/i',
            'Artificial Intelligence'     => '/\b(artificial\s+intelligence|kecerdasan\s+buatan)\b/i',
            'Exploratory Data Analysis'   => '/\b(exploratory\s+data\s+analysis|eda)\b/i',
            'Data Visualization'          => '/\bdata\s+visuali[zs]ation\b/i',
            'AI Engineering'              => '/\bai\s+engineering\b/i',
            'CNN'                         => '/\b(cnn|convolutional\s+neural\s+network(s)?)\b/i',
            'LLM'                         => '/\b(llm|large\s+language\s+model(s)?)\b/i',
            'Natural Language Processing' => '/\b(nlp|natural\s+language\s+processing)\b/i',
            'Computer Vision'             => '/\bcomputer\s+vision\b/i',
            'Prompt Engineering'          => '/\bprompt\s+engineering\b/i',
            'Generative AI'               => '/\b(generative\s+ai|gen[\s\-]?ai)\b/i',
            'TensorFlow'                  => '/\btensorflow\b/i',
            'PyTorch'                     => '/\bpytorch\b/i',
            'Scikit-Learn'                => '/\bscikit[\s\-]learn\b/i',
            'Pandas'                      => '/\bpandas\b/i',
            'NumPy'                       => '/\bnumpy\b/i',
            'Tableau'                     => '/\btableau\b/i',
            'Power BI'                    => '/\bpower[\s\-]?bi\b/i',
            'Big Data'                    => '/\bbig[\s\-]data\b/i',
            'Apache Spark'                => '/\b(apache\s*)?spark\b/i',
            'Statistics'                  => '/\b(statistics|statistika)\b/i',
            'SPSS'                        => '/\bspss\b/i',
            'SQL'                         => '/\bsql\b/i',

            // 3. BISNIS, MANAJEMEN & OPERASIONAL
            'Business Analysis'           => '/\bbusiness\s+analy(sis|st)\b/i',
            'Business Development'        => '/\bbusiness\s+development\b/i',
            'Project Management'          => '/\bproject\s+management\b/i',
            'Product Management'          => '/\bproduct\s+management\b/i',
            'Agile / Scrum'               => '/\b(agile|scrum)\b/i',
            'Operations Management'       => '/\b(operations?\s+management|manajemen\s+operasional)\b/i',
            'Supply Chain Management'     => '/\b(supply\s+chain|rantai\s+pasok)\b/i',
            'Logistics'                   => '/\b(logistics|logistik)\b/i',
            'Procurement'                 => '/\b(procurement|pengadaan)\b/i',
            'Strategic Planning'          => '/\b(strategic\s+planning|perencanaan\s+strategis)\b/i',
            'Market Research'             => '/\b(market\s+research|riset\s+pasar)\b/i',
            'ERP / SAP'                   => '/\b(erp|sap)\b/i',
            'CRM'                         => '/\bcrm\b/i',
            'Lean Management'             => '/\blean\s+management\b/i',

            // 4. KEUANGAN, AKUNTANSI & PERBANKAN
            'Akuntansi'                   => '/\b(akuntansi|accounting)\b/i',
            'Financial Analysis'          => '/\bfinancial\s+analys(is|t)\b/i',
            'Financial Modeling'          => '/\bfinancial\s+modeling\b/i',
            'Bookkeeping'                 => '/\b(bookkeeping|pembukuan)\b/i',
            'Perpajakan'                  => '/\b(perpajakan|pajak|taxation|tax)\b/i',
            'Brevet A/B'                  => '/\bbrevet\s*(a|b|ab)\b/i',
            'Auditing'                    => '/\b(auditing|audit)\b/i',
            'Corporate Finance'           => '/\bcorporate\s+finance\b/i',
            'Excel'                       => '/\b(excel|spreadsheets?)\b/i',
            'Accurate'                    => '/\baccurate\b/i',
            'MYOB'                        => '/\bmyob\b/i',
            'Cash Flow Management'        => '/\bcash\s+flow\b/i',
            'Budgeting'                   => '/\bbudgeting\b/i',

            // 5. MARKETING, KOMUNIKASI & MEDIA
            'Digital Marketing'           => '/\bdigital\s+marketing\b/i',
            'Social Media Management'     => '/\bsocial\s+media\b/i',
            'SEO / SEM'                   => '/\b(seo|sem)\b/i',
            'Content Creation'            => '/\bcontent\s+creat(or|ion)\b/i',
            'Content Writing'             => '/\bcontent\s+writing\b/i',
            'Copywriting'                 => '/\b(copywriting|copywriter)\b/i',
            'Public Relations'            => '/\b(public\s+relations|humas)\b/i',
            'Brand Management'            => '/\bbrand(ing)?\b/i',
            'Google Ads'                  => '/\bgoogle\s+ads\b/i',
            'Meta Ads'                    => '/\b(meta|facebook|instagram)\s+ads\b/i',
            'Email Marketing'             => '/\bemail\s+marketing\b/i',
            'Public Speaking'             => '/\bpublic\s+speaking\b/i',
            'Event Management'            => '/\bevent\s+(management|organizer)\b/i',

            // 6. DESAIN, KREATIF & SENI
            'UI / UX'                     => '/\bui[\/\s\-]?ux\b/i',
            'Figma'                       => '/\bfigma\b/i',
            'Graphic Design'              => '/\b(graphic\s+design|desain\s+grafis)\b/i',
            'Adobe Photoshop'             => '/\b(adobe\s*photoshop|photoshop)\b/i',
            'Adobe Illustrator'           => '/\b(adobe\s*illustrator|illustrator)\b/i',
            'Adobe Premiere Pro'          => '/\b(premiere\s+pro|premiere)\b/i',
            'Adobe After Effects'         => '/\bafter\s+effects\b/i',
            'Video Editing'               => '/\bvideo\s+edit(ing|or)\b/i',
            'Motion Graphics'             => '/\bmotion\s+graphics\b/i',
            'Photography'                 => '/\b(photography|fotografi)\b/i',
            'Videography'                 => '/\b(videography|videografi)\b/i',
            '3D Modeling'                 => '/\b3d\s+model(ing)?\b/i',
            'Blender'                     => '/\bblender\b/i',
            'Canva'                       => '/\bcanva\b/i',

            // 7. TEKNIK (ENGINEERING NON-IT)
            'AutoCAD'                     => '/\bautocad\b/i',
            'SolidWorks'                  => '/\bsolidworks\b/i',
            'MATLAB'                      => '/\bmatlab\b/i',
            'PLC'                         => '/\bplc\b/i',
            'Mekatronika'                 => '/\bmekatronika\b/i',
            'Gambar Teknik'               => '/\bgambar\s+teknik\b/i',
            'K3 (HSE)'                    => '/\b(k3|hse|keselamatan\s+kerja)\b/i',
            'Desain Struktur'             => '/\bdesain\s+struktur\b/i',

            // 8. HUKUM & LEGALITAS
            'Legal Research'              => '/\blegal\s+research\b/i',
            'Legal Drafting'              => '/\blegal\s+drafting\b/i',
            'Contract Management'         => '/\bcontract\s+management\b/i',
            'Corporate Law'               => '/\bcorporate\s+law\b/i',
            'Litigasi'                    => '/\blitigasi\b/i',
            'Kepatuhan Regulasi'          => '/\b(compliance|kepatuhan)\b/i',
            'HAKI'                        => '/\b(haki|hak\s+cipta|paten)\b/i',

            // 9. KESEHATAN & MEDIS
            'Keperawatan'                 => '/\b(keperawatan|nursing)\b/i',
            'Farmasi'                     => '/\b(farmasi|pharmacy)\b/i',
            'Pelayanan Klinis'            => '/\bpelayanan\s+klinis\b/i',
            'Public Health'               => '/\b(public\s+health|kesehatan\s+masyarakat)\b/i',
            'Rekam Medis'                 => '/\brekam\s+medis\b/i',
            'Konseling Psikologi'         => '/\b(konseling|counseling)\b/i',

            // 10. SOFT SKILLS & KEMAMPUAN UMUM
            'Communication'               => '/\b(communication|komunikasi)\b/i',
            'Leadership'                  => '/\b(leadership|kepemimpinan)\b/i',
            'Teamwork'                    => '/\b(teamwork|kerja\s*tim|kolaborasi)\b/i',
            'Problem Solving'             => '/\bproblem[\s\-]solving\b/i',
            'Critical Thinking'           => '/\bcritical\s+thinking\b/i',
            'Time Management'             => '/\btime\s+management\b/i',
            'Negosiasi'                   => '/\b(negotiation|negosiasi)\b/i',
            'Presentation Skills'         => '/\bpresentasi\b/i',
            'Customer Service'            => '/\bcustomer\s+service\b/i',
            'Bahasa Inggris'              => '/\b(bahasa\s+inggris|english|toefl|ielts)\b/i',
            'Adaptabilitas'               => '/\b(adaptability|adaptabilitas)\b/i',
        ];
    }
}
