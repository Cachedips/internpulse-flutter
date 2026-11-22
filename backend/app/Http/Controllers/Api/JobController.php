<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CustomJob;
use App\Services\RemotiveService;
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

        // Lowongan lokal (admin) + lowongan global (Remotive)
        $local = CustomJob::where('is_active', true)
            ->latest()
            ->get()
            ->map(fn (CustomJob $j) => $this->fromCustom($j));

        $global = collect($remotive->internships());

        // ---- Filter lokasi ----
        if ($location !== '') {
            $loc = mb_strtolower($location);

            $local = $local->filter(
                fn ($j) => str_contains(mb_strtolower($j['location']), $loc)
            );

            // Lowongan Remotive hanya relevan untuk "Remote" dan "Luar Negeri"
            if (! in_array($loc, ['remote', 'luar negeri'], true)) {
                $global = collect();
            }
        }

        // ---- Filter jurusan ----
        if ($major !== '') {
            $matchMajor = fn ($j) => ($j['major_category'] ?: 'Lainnya') === $major;
            $local  = $local->filter($matchMajor);
            $global = $global->filter($matchMajor);
        }

        // ---- Pencarian teks ----
        if ($search !== '') {
            $matchSearch = fn ($j) => str_contains(
                mb_strtolower($j['job_title'] . ' ' . $j['company_name'] . ' ' . $j['job_requirements']),
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
