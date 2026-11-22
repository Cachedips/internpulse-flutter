<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class TrackerController extends Controller
{
    private const STATUSES = ['saved', 'applied', 'interview', 'accepted', 'rejected'];
    private const STIPENDS = ['paid', 'unpaid', 'unknown'];

    // GET /api/trackers -> {data:[...]}
    public function index(Request $request): JsonResponse
    {
        $items = $request->user()->trackers()->latest('updated_at')->get();

        return response()->json(['data' => $items]);
    }

    // POST /api/trackers -> {data: tracker}
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'company_name'     => 'required|string|max:255',
            'job_title'        => 'required|string|max:255',
            'location'         => 'nullable|string|max:100',
            'major_category'   => 'nullable|string|max:100',
            'job_url'          => 'nullable|string',
            'job_requirements' => 'nullable|string',
            'stipend_type'     => ['nullable', Rule::in(self::STIPENDS)],
            'status'           => ['nullable', Rule::in(self::STATUSES)],
            'personal_notes'   => 'nullable|string',
        ]);

        $status = $data['status'] ?? 'saved';

        // Lowongan yang sama tidak dibuat dobel: cukup perbarui statusnya.
        $existing = $request->user()->trackers()
            ->where('company_name', $data['company_name'])
            ->where('job_title', $data['job_title'])
            ->first();

        if ($existing) {
            if ($existing->status !== $status) {
                $existing->update(['status' => $status]);
            }
            return response()->json(['data' => $existing->fresh()]);
        }

        $tracker = $request->user()->trackers()->create([
            'company_name'     => $data['company_name'],
            'job_title'        => $data['job_title'],
            'location'         => $data['location'] ?? 'Remote',
            'major_category'   => $data['major_category'] ?? null,
            'job_url'          => $data['job_url'] ?? null,
            'job_requirements' => isset($data['job_requirements'])
                ? Str::limit($data['job_requirements'], 8000, '')
                : null,
            'stipend_type'     => $data['stipend_type'] ?? 'unknown',
            'status'           => $status,
            'personal_notes'   => $data['personal_notes'] ?? null,
        ]);

        return response()->json(['data' => $tracker->fresh()], 201);
    }

    // PUT /api/trackers/{id} -> {data: tracker}
    public function update(Request $request, $id): JsonResponse
    {
        $tracker = $request->user()->trackers()->findOrFail($id);

        $data = $request->validate([
            'company_name'   => 'sometimes|string|max:255',
            'job_title'      => 'sometimes|string|max:255',
            'location'       => 'sometimes|string|max:100',
            'job_url'        => 'sometimes|nullable|string',
            'stipend_type'   => ['sometimes', Rule::in(self::STIPENDS)],
            'status'         => ['sometimes', Rule::in(self::STATUSES)],
            'personal_notes' => 'sometimes|nullable|string',
        ]);

        $tracker->update($data);

        return response()->json(['data' => $tracker->fresh()]);
    }

    // PATCH /api/trackers/{id}/status -> {data: tracker}
    public function updateStatus(Request $request, $id): JsonResponse
    {
        $tracker = $request->user()->trackers()->findOrFail($id);

        $data = $request->validate([
            'status' => ['required', Rule::in(self::STATUSES)],
        ]);

        $tracker->update(['status' => $data['status']]);

        return response()->json(['data' => $tracker->fresh()]);
    }

    // DELETE /api/trackers/{id}
    public function destroy(Request $request, $id): JsonResponse
    {
        $request->user()->trackers()->findOrFail($id)->delete();

        return response()->json(['message' => 'Lamaran dihapus']);
    }
}
