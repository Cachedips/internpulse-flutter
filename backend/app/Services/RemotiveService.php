<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class RemotiveService
{
    private const CACHE_KEY = 'remotive_internships';
    // Remotive meminta penggunaan API tidak terlalu sering, jadi hasilnya di-cache 6 jam.
    private const CACHE_TTL = 21600;

    /**
     * Ambil lowongan magang dari Remotive dan ubah ke format aplikasi.
     */
    public function internships(): array
    {
        $cached = Cache::get(self::CACHE_KEY);
        if ($cached !== null) {
            return $cached;
        }

        try {
            $verify = filter_var(env('HTTP_VERIFY_SSL', true), FILTER_VALIDATE_BOOLEAN);

            $response = Http::timeout(20)
                ->withOptions(['verify' => $verify])
                ->acceptJson()
                ->get('https://remotive.com/api/remote-jobs', [
                    'search' => 'intern',
                    'limit'  => 80,
                ]);

            if (! $response->successful()) {
                Log::warning('Remotive API gagal: HTTP ' . $response->status());
                return [];
            }

            $jobs = collect($response->json('jobs', []))
                ->map(fn ($j) => $this->normalize($j))
                ->values()
                ->all();

            Cache::put(self::CACHE_KEY, $jobs, self::CACHE_TTL);

            return $jobs;
        } catch (\Throwable $e) {
            // Jangan cache kegagalan agar request berikutnya mencoba lagi.
            Log::warning('Remotive API error: ' . $e->getMessage());
            return [];
        }
    }

    private function normalize(array $j): array
    {
        $title       = (string) ($j['title'] ?? '-');
        $description = $this->cleanHtml((string) ($j['description'] ?? ''));
        $salary      = trim((string) ($j['salary'] ?? ''));
        $candidateLoc = trim((string) ($j['candidate_required_location'] ?? ''));

        $requirements = $description;
        if ($candidateLoc !== '') {
            $requirements = "Lokasi kandidat: {$candidateLoc}\n\n" . $requirements;
        }

        return [
            'id'               => 'remotive-' . ($j['id'] ?? Str::random(6)),
            'source'           => 'remotive',
            'company_name'     => $j['company_name'] ?? '-',
            'job_title'        => $title,
            'location'         => 'Remote',
            'major_category'   => $this->mapCategory((string) ($j['category'] ?? '')),
            'stipend_type'     => StipendDetector::detect($salary, $title . ' ' . $description),
            'salary_range'     => $salary !== '' ? $salary : null,
            'job_requirements' => Str::limit($requirements, 3000),
            'job_url'          => $j['url'] ?? null,
        ];
    }

    /** HTML -> teks polos. */
    private function cleanHtml(string $html): string
    {
        $html = preg_replace('/<\s*br\s*\/?>|<\/p>|<\/li>|<\/h[1-6]>/i', "\n", $html);
        $text = html_entity_decode(strip_tags($html), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $text = preg_replace("/[ \t]+/", ' ', $text);
        $text = preg_replace("/\n{3,}/", "\n\n", $text);

        return trim($text);
    }

    /** Kategori Remotive -> kategori jurusan aplikasi. */
    private function mapCategory(string $category): string
    {
        $c = mb_strtolower(trim($category));

        if (str_contains($c, 'software') || str_contains($c, 'devops') || str_contains($c, 'data') || $c === 'qa') {
            return 'Informatika/SI';
        }
        if (str_contains($c, 'design')) {
            return 'DKV';
        }
        if (str_contains($c, 'marketing') || str_contains($c, 'sales') || str_contains($c, 'customer')
            || str_contains($c, 'product') || str_contains($c, 'project') || str_contains($c, 'human')) {
            return 'Manajemen/Pemasaran';
        }
        if (str_contains($c, 'finance') || str_contains($c, 'legal')) {
            return 'Akuntansi/Keuangan';
        }

        return 'Lainnya';
    }
}
