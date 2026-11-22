<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ApplicationTracker extends Model
{
    protected $fillable = [
        'user_id',
        'company_name',
        'job_title',
        'location',
        'major_category',
        'job_url',
        'job_requirements',
        'stipend_type',
        'status',
        'ai_match_score',
        'ai_feedback',
        'ai_followup_email',
        'interview_logs',
        'personal_notes',
    ];

    protected $casts = [
        'ai_match_score' => 'integer',
        'ai_feedback'    => 'array',
        'interview_logs' => 'array',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
