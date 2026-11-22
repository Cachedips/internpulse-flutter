<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('application_trackers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('company_name', 255);
            $table->string('job_title', 255);
            $table->string('location', 100)->default('Remote');
            $table->string('major_category', 100)->nullable();
            $table->text('job_url')->nullable();
            $table->text('job_requirements')->nullable();
            $table->enum('stipend_type', ['paid', 'unpaid', 'unknown'])->default('unknown');
            $table->enum('status', ['saved', 'applied', 'interview', 'accepted', 'rejected'])->default('saved');
            $table->unsignedInteger('ai_match_score')->nullable();
            $table->json('ai_feedback')->nullable();
            $table->text('ai_followup_email')->nullable();
            $table->json('interview_logs')->nullable();
            $table->text('personal_notes')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('application_trackers');
    }
};
