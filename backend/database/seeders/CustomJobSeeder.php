<?php

namespace Database\Seeders;

use App\Models\CustomJob;
use Illuminate\Database\Seeder;

/**
 * Data contoh lowongan lokal (fiktif) untuk pengujian.
 * Ganti/hapus nanti lewat Admin Panel.
 * Jalankan: php artisan db:seed --class=CustomJobSeeder
 */
class CustomJobSeeder extends Seeder
{
    public function run(): void
    {
        $jobs = [
            [
                'company_name'     => 'PT Nusantara Digital (contoh)',
                'job_title'        => 'Frontend Developer Intern',
                'location'         => 'Surabaya',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 1.500.000 - Rp 2.500.000 / bulan',
                'job_requirements' => "Mahasiswa semester 5 ke atas jurusan Informatika/SI.\nMenguasai HTML, CSS, JavaScript.\nPaham dasar React atau Flutter.\nMemahami Git dan REST API.\nMampu bekerja dalam tim.",
                'application_link' => 'https://example.com/lamar/frontend-intern',
            ],
            [
                'company_name'     => 'Studio Kreatif Arek (contoh)',
                'job_title'        => 'UI/UX Design Intern',
                'location'         => 'Surabaya',
                'major_category'   => 'DKV',
                'stipend_type'     => 'allowance',
                'salary_range'     => 'Uang saku + transport',
                'job_requirements' => "Mahasiswa DKV atau Desain Produk.\nMenguasai Figma.\nMemahami prinsip UI/UX dan design system.\nMemiliki portofolio.\nMampu presentasi desain.",
                'application_link' => 'https://example.com/lamar/uiux-intern',
            ],
            [
                'company_name'     => 'CV Maju Bersama (contoh)',
                'job_title'        => 'Digital Marketing Intern',
                'location'         => 'Surabaya',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'unpaid',
                'salary_range'     => null,
                'job_requirements' => "Mahasiswa Manajemen/Pemasaran/Komunikasi.\nPaham dasar social media marketing.\nMampu membuat konten sederhana (Canva).\nKomunikatif dan kreatif.",
                'application_link' => 'https://example.com/lamar/marketing-intern',
            ],
            [
                'company_name'     => 'PT Sinergi Teknologi Jakarta (contoh)',
                'job_title'        => 'Data Analyst Intern',
                'location'         => 'Jakarta',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 3.000.000 / bulan',
                'job_requirements' => "Menguasai SQL dan Excel.\nPaham dasar Python (pandas).\nMampu membuat dashboard (Power BI/Tableau).\nTeliti dan analitis.",
                'application_link' => 'https://example.com/lamar/data-intern',
            ],
            [
                'company_name'     => 'Inovasi Listrik Mandiri (contoh)',
                'job_title'        => 'IoT & Electrical Engineer Intern',
                'location'         => 'Surabaya',
                'major_category'   => 'Teknik Elektro',
                'stipend_type'     => 'allowance',
                'salary_range'     => 'Uang makan + transport',
                'job_requirements' => "Mahasiswa Teknik Elektro.\nPaham mikrokontroler (Arduino/ESP32).\nBisa membaca rangkaian dan skematik.\nDasar pemrograman C/C++.",
                'application_link' => 'https://example.com/lamar/iot-intern',
            ],
            [
                'company_name'     => 'Kampus Media Unesa (contoh)',
                'job_title'        => 'Content Writer Intern',
                'location'         => 'Remote',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'unpaid',
                'salary_range'     => null,
                'job_requirements' => "Mampu menulis artikel dalam Bahasa Indonesia dan Inggris.\nPaham dasar SEO.\nMemiliki contoh tulisan.\nDisiplin terhadap tenggat waktu.",
                'application_link' => 'https://example.com/lamar/writer-intern',
            ],
        ];

        foreach ($jobs as $job) {
            CustomJob::updateOrCreate(
                ['company_name' => $job['company_name'], 'job_title' => $job['job_title']],
                $job + ['is_active' => true]
            );
        }
    }
}
