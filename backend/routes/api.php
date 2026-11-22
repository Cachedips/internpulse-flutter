<?php

use App\Http\Controllers\Api\AiController;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\JobController;
use App\Http\Controllers\Api\TrackerController;
use Illuminate\Support\Facades\Route;

// ---------- Public ----------
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// ---------- Protected (Bearer token Sanctum) ----------
Route::middleware('auth:sanctum')->group(function () {
    // Auth & profil
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);
    Route::put('/profile', [AuthController::class, 'updateProfile']);
    Route::post('/profile/extract-cv', [AnalyticsController::class, 'extractCv']);

    // Job feed (Remotive + lowongan lokal)
    Route::get('/jobs', [JobController::class, 'index']);
    Route::post('/jobs/skill-gap', [AnalyticsController::class, 'skillGap']);

    // Market Analytics & Scarcity Index
    Route::get('/analytics/market-trends', [AnalyticsController::class, 'marketTrends']);
    Route::get('/analytics/skill-scarcity', [AnalyticsController::class, 'skillScarcity']);

    // Kanban tracker
    Route::get('/trackers', [TrackerController::class, 'index']);
    Route::post('/trackers', [TrackerController::class, 'store']);
    Route::put('/trackers/{id}', [TrackerController::class, 'update']);
    Route::patch('/trackers/{id}/status', [TrackerController::class, 'updateStatus']);
    Route::delete('/trackers/{id}', [TrackerController::class, 'destroy']);

    // Gen AI (Gemini)
    Route::post('/jobs/analyze', [AiController::class, 'analyzeJob']);
    Route::get('/trackers/insights', [AiController::class, 'insights']);
    Route::post('/trackers/{id}/followup', [AiController::class, 'followup']);
    Route::post('/trackers/{id}/interview/question', [AiController::class, 'interviewQuestion']);
    Route::post('/trackers/{id}/interview/answer', [AiController::class, 'interviewAnswer']);

    // TODO tahap berikutnya:
    // POST /trackers/report/pdf-link  (laporan PDF)
});
