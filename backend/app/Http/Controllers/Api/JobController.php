<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomJob;
use App\Services\RemotiveService;
use Database\Seeders\CustomJobSeeder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class JobController extends Controller
{
    // GET /api/jobs?location=&major=&search=  -> {data:[...]}
    public function index(Request $request, RemotiveService $remotive): JsonResponse
    {
        $location = trim((string) $request->query('location', ''));
        $major    = trim((string) $request->query('major', ''));
        $search   = mb_strtolower(trim((string) $request->query('search', '')));

        // Otomatis jalankan seeding jika data lowongan masih kosong atau kurang dari 25
        try {
            if (CustomJob::where('is_active', true)->count() < 25) {
                CustomJobSeeder::seedJobs();
            }
        } catch (\Throwable $e) {
            // Abaikan jika database connection belum siap
        }

        // Lowongan lokal (admin & database) + lowongan global (Remotive)
        $local = CustomJob::where('is_active', true)
            ->latest()
            ->get()
            ->map(fn (CustomJob $j) => $this->fromCustom($j));

        $global = collect($remotive->internships());

        // ---- Filter lokasi ----
        if ($location !== '' && mb_strtolower($location) !== 'semua') {
            $loc = mb_strtolower($location);

            if (str_contains($loc, 'remote') || str_contains($loc, 'luar negeri') || str_contains($loc, 'global')) {
                // Filter lowongan yang bersifat remote atau luar negeri
                $local = $local->filter(function ($j) {
                    $l = mb_strtolower($j['location']);
                    return str_contains($l, 'remote')
                        || str_contains($l, 'singapore')
                        || str_contains($l, 'australia')
                        || str_contains($l, 'sydney')
                        || str_contains($l, 'japan')
                        || str_contains($l, 'tokyo')
                        || str_contains($l, 'europe')
                        || str_contains($l, 'berlin')
                        || str_contains($l, 'london')
                        || str_contains($l, 'us')
                        || str_contains($l, 'global')
                        || str_contains($l, 'luar negeri');
                });
                // Lowongan Remotive juga bersifat remote & global
            } elseif (str_contains($loc, 'jakarta')) {
                $local = $local->filter(
                    fn ($j) => str_contains(mb_strtolower($j['location']), 'jakarta')
                );
                $global = collect(); // Lowongan Remotive bukan onsite Jakarta
            } elseif (str_contains($loc, 'surabaya')) {
                $local = $local->filter(
                    fn ($j) => str_contains(mb_strtolower($j['location']), 'surabaya')
                );
                $global = collect(); // Lowongan Remotive bukan onsite Surabaya
            } else {
                $local = $local->filter(
                    fn ($j) => str_contains(mb_strtolower($j['location']), $loc)
                );
                if (! in_array($loc, ['remote', 'luar negeri', 'global'], true)) {
                    $global = collect();
                }
            }
        }

        // ---- Filter jurusan ----
        if ($major !== '' && mb_strtolower($major) !== 'semua jurusan') {
            $matchMajor = fn ($j) => ($j['major_category'] ?: 'Lainnya') === $major;
            $local  = $local->filter($matchMajor);
            $global = $global->filter($matchMajor);
        }

        // ---- Pencarian teks ----
        if ($search !== '') {
            $matchSearch = fn ($j) => str_contains(
                mb_strtolower($j['job_title'] . ' ' . $j['company_name'] . ' ' . $j['job_requirements'] . ' ' . $j['location']),
                $search
            );
            $local  = $local->filter($matchSearch);
            $global = $global->filter($matchSearch);
        }

        $data = $local->concat($global)->values()->take(100);

        return response()->json(['data' => $data]);
    }

    private function fromCustom(CustomJob $j): array
    {
        return [
            'id'               => 'local-' . $j->id,
            'source'           => 'local',
            'company_name'     => $j->company_name,
            'job_title'        => $j->job_title,
            'location'         => $j->location,
            'major_category'   => $j->major_category,
            'stipend_type'     => $j->stipend_type,
            'salary_range'     => $j->salary_range,
            'job_requirements' => $j->job_requirements,
            'job_url'          => $j->application_link,
        ];
    }
}
