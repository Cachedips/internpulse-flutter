<?php

use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Route;

// ---------- Public ----------
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// ---------- Protected (Bearer token Sanctum) ----------
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/profile', [AuthController::class, 'updateProfile']);

    // TODO tahap berikutnya:
    // GET  /jobs, POST /jobs/analyze
    // CRUD /trackers, PATCH /trackers/{id}/status
    // GET  /trackers/insights, POST /trackers/{id}/followup
    // POST /trackers/{id}/interview/question|answer
    // POST /trackers/report/pdf-link
});
