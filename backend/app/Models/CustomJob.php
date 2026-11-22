<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class CustomJob extends Model
{
    protected $fillable = [
        'company_name',
        'job_title',
        'location',
        'major_category',
        'stipend_type',
        'salary_range',
        'job_requirements',
        'application_link',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];
}
