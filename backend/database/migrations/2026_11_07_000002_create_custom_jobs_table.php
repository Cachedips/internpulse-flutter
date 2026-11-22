<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('custom_jobs', function (Blueprint $table) {
            $table->id();
            $table->string('company_name', 255);
            $table->string('job_title', 255);
            $table->string('location', 100);
            $table->string('major_category', 100)->nullable();
            $table->enum('stipend_type', ['paid', 'unpaid', 'allowance'])->default('unpaid');
            $table->string('salary_range', 100)->nullable();
            $table->text('job_requirements');
            $table->text('application_link')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('custom_jobs');
    }
};
