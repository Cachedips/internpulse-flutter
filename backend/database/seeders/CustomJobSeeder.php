<?php

namespace Database\Seeders;

use App\Models\CustomJob;
use Illuminate\Database\Seeder;

/**
 * Data lowongan magang realistis untuk Jakarta, Surabaya, dan Remote / Luar Negeri.
 * Jalankan: php artisan db:seed --class=CustomJobSeeder
 */
class CustomJobSeeder extends Seeder
{
    public function run(): void
    {
        self::seedJobs();
    }

    public static function seedJobs(): void
    {
        $jobs = self::getDefaultJobs();

        foreach ($jobs as $job) {
            CustomJob::updateOrCreate(
                [
                    'company_name' => $job['company_name'],
                    'job_title'    => $job['job_title'],
                ],
                $job + ['is_active' => true]
            );
        }
    }

    public static function getDefaultJobs(): array
    {
        return [
            // ==========================================
            // JAKARTA (10 Lowongan)
            // ==========================================
            [
                'company_name'     => 'PT GoTo Gojek Tokopedia Tbk',
                'job_title'        => 'Mobile Flutter & Android Developer Intern',
                'location'         => 'Jakarta Selatan (SCBD)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.500.000 - Rp 6.000.000 / bulan',
                'job_requirements' => "Mahasiswa tingkat akhir atau fresh graduate Informatika, Sistem Informasi, atau ilmu komputer terkait.\nKeahlian wajib: Flutter, Dart, REST API, Git, Mobile Application Development, State Management (Provider/Bloc).\nNilai tambah: Pengalaman unit testing, CI/CD mobile, integrasi payment gateway.\nMampu bekerja agile dalam sprint tim lintas fungsi.",
                'application_link' => 'https://careers.gotocompany.com/jobs/flutter-intern',
            ],
            [
                'company_name'     => 'PT Bank Central Asia Tbk (BCA)',
                'job_title'        => 'Data Science & Machine Learning Intern',
                'location'         => 'Jakarta Pusat (Menara BCA Sudirman)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 5.000.000 / bulan',
                'job_requirements' => "Mahasiswa aktif Ilmu Komputer, Matematika, Statistika, atau Sains Data.\nKeahlian wajib: Python, SQL, Pandas, NumPy, Machine Learning, Exploratory Data Analysis, Data Visualization (Tableau/Power BI).\nMemahami konsep algoritma klasifikasi, regresi, dan pengolahan data terstruktur skala besar.\nKemampuan komunikasi analitis dan berpikir kritis.",
                'application_link' => 'https://karir.bca.co.id/opportunities/data-science-intern',
            ],
            [
                'company_name'     => 'PT Shopee International Indonesia',
                'job_title'        => 'UI/UX Product Designer Intern',
                'location'         => 'Jakarta Selatan (Pacific Century Place, SCBD)',
                'major_category'   => 'DKV',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.500.000 / bulan',
                'job_requirements' => "Mahasiswa Desain Komunikasi Visual (DKV), Desain Produk, atau Human-Computer Interaction.\nKeahlian wajib: Figma, Design System, Wireframing, User Research, Prototyping, Usability Testing.\nMemiliki portofolio interaktif studi kasus web atau mobile app.\nKreatif, memperhatikan detail micro-interaction, dan memahami user journey e-commerce.",
                'application_link' => 'https://careers.shopee.co.id/jobs/uiux-intern',
            ],
            [
                'company_name'     => 'PT Astra International Tbk',
                'job_title'        => 'Business Development & Strategic Planning Intern',
                'location'         => 'Jakarta Utara (Menara Astra Sunter)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.000.000 / bulan',
                'job_requirements' => "Mahasiswa Manajemen Bisnis, Ekonomi, Teknik Industri, atau Administrasi Bisnis.\nKeahlian wajib: Business Analysis, Market Research, Financial Modeling Dasar, Microsoft Excel / Spreadsheet (Advanced), Presentasi & Pitching.\nTerbiasa menyusun competitive landscape dan proposal kerjasama kemitraan.\nKeterampilan negosiasi dan bahasa Inggris aktif.",
                'application_link' => 'https://career.astra.co.id/vacancies/bizdev-intern',
            ],
            [
                'company_name'     => 'PT Ernst & Young Indonesia (EY)',
                'job_title'        => 'Financial & Audit Analyst Intern',
                'location'         => 'Jakarta Selatan (Indonesia Stock Exchange Tower SCBD)',
                'major_category'   => 'Akuntansi/Keuangan',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.500.000 / bulan',
                'job_requirements' => "Mahasiswa semester 6-8 jurusan Akuntansi, Keuangan, atau Perbankan (IPK minimal 3.30).\nKeahlian wajib: PSAK / IFRS, Financial Statement Analysis, Audit Dasar, Microsoft Excel (VLOOKUP, Pivot, Index Match), Rekonsiliasi Bank.\nMemahami prinsip perpajakan Indonesia (PPh 21, 23, PPN) adalah nilai tambah besar.\nIntegritas tinggi, teliti dalam angka, dan siap bekerja dalam ritme dinamis.",
                'application_link' => 'https://www.ey.com/en_id/careers/audit-internship-jakarta',
            ],
            [
                'company_name'     => 'PT Unilever Indonesia Tbk',
                'job_title'        => 'Brand & Digital Marketing Intern',
                'location'         => 'Jakarta Selatan (BSD / Kuningan)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.200.000 / bulan',
                'job_requirements' => "Mahasiswa Manajemen Pemasaran, Ilmu Komunikasi, Public Relations, atau Advertising.\nKeahlian wajib: Digital Marketing Strategy, Social Media Campaign Management, Copywriting, Content Creation (Canva/CapCut), Google Analytics, KOL/Influencer Management.\nKreatif dalam mengikuti tren media sosial (TikTok, Instagram) dan berorientasi data performa (ROAS/Engagement Rate).",
                'application_link' => 'https://careers.unilever.co.id/jobs/marketing-intern',
            ],
            [
                'company_name'     => 'DANA Indonesia (PT Espay Debit Indonesia Koe)',
                'job_title'        => 'Backend Software Engineer (Go / Laravel) Intern',
                'location'         => 'Jakarta Selatan (Gatot Subroto)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.800.000 / bulan',
                'job_requirements' => "Mahasiswa Teknik Informatika, Ilmu Komputer, atau Rekayasa Perangkat Lunak.\nKeahlian wajib: Golang atau PHP (Laravel), RESTful API Design, SQL (PostgreSQL/MySQL), Redis, Git.\nMemahami dasar arsitektur microservices, concurrency, dan keamanan data transaksi.\nKemampuan memecahkan masalah algoritma dan struktur data yang baik.",
                'application_link' => 'https://dana.id/careers/backend-intern',
            ],
            [
                'company_name'     => 'Blibli (PT Global Digital Niaga Tbk)',
                'job_title'        => 'Quality Assurance (QA) Automation Intern',
                'location'         => 'Jakarta Pusat (Grand Indonesia)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.000.000 / bulan',
                'job_requirements' => "Mahasiswa Teknik Informatika atau Sistem Informasi.\nKeahlian wajib: Software Testing Life Cycle (STLC), Test Case Writing, Postman (API Testing), Automation Dasar (Selenium / Cypress / Appium), Git.\nDetail-oriented dalam menemukan bug dan mampu menyusun laporan bug di Jira.",
                'application_link' => 'https://careers.blibli.com/jobs/qa-intern',
            ],
            [
                'company_name'     => 'Traveloka Indonesia',
                'job_title'        => 'Product Management Associate Intern',
                'location'         => 'Jakarta Selatan (South Quarter Tower)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 5.000.000 / bulan',
                'job_requirements' => "Mahasiswa tingkat akhir dari semua jurusan (diutamakan Teknik Informatika, Sistem Informasi, Bisnis, atau Desain).\nKeahlian wajib: Product Requirements Document (PRD), User Story Mapping, Prioritization Framework (RICE/MoSCoW), Data-Driven Decision Making, Agile/Scrum.\nKemampuan komunikasi lintas tim (Engineering, UX, Business).",
                'application_link' => 'https://www.traveloka.com/en-id/careers/product-intern',
            ],
            [
                'company_name'     => 'PT Telkom Indonesia (Persero) Tbk',
                'job_title'        => 'IoT & Smart Device Solutions Intern',
                'location'         => 'Jakarta Barat (Telkom Landmark Hub)',
                'major_category'   => 'Teknik Elektro',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 4.000.000 / bulan',
                'job_requirements' => "Mahasiswa Teknik Elektro, Teknik Komputer, atau Mekatronika.\nKeahlian wajib: Mikrokontroler (ESP32, STM32, Arduino), Pemrograman C/C++, Protokol IoT (MQTT, HTTP, CoAP), Desain Skematik PCB Dasar (Eagle/KiCad).\nPaham integrasi sensor cerdas dan dashboard cloud IoT.",
                'application_link' => 'https://careers.telkom.co.id/vacancies/iot-intern',
            ],

            // ==========================================
            // SURABAYA (10 Lowongan)
            // ==========================================
            [
                'company_name'     => 'PT Nusantara Digital Kreasi',
                'job_title'        => 'Frontend React & Flutter Developer Intern',
                'location'         => 'Surabaya Timur (MERR Rungkut)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 2.500.000 - Rp 3.500.000 / bulan',
                'job_requirements' => "Mahasiswa semester 5 ke atas di Surabaya dan sekitarnya (ITS, Unesa, PENS, UPN, Ubaya).\nKeahlian wajib: React.js, Flutter, JavaScript, HTML5/CSS3, Tailwind CSS, REST API, Git.\nMampu menerjemahkan desain Figma menjadi komponen responsif dan pixel-perfect.\nSemangat belajar tinggi dan terbiasa bekerja dalam tim.",
                'application_link' => 'https://nusantaradigital.id/karir/frontend-intern-sby',
            ],
            [
                'company_name'     => 'Surabaya AI Lab & Analytics Center',
                'job_title'        => 'Junior Data Analyst & Business Intelligence Intern',
                'location'         => 'Surabaya Barat (Mayjen Sungkono)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 3.000.000 / bulan',
                'job_requirements' => "Mahasiswa Sistem Informasi, Sains Data, Teknik Informatika, atau Statistika.\nKeahlian wajib: SQL Querying, Microsoft Power BI / Tableau, Python Data Cleaning (Pandas), Dashboarding, Excel Spreadsheet.\nMampu menggali insight bisnis dari data penjualan serta mempresentasikannya ke stakeholder.",
                'application_link' => 'https://sbyailab.id/internship/data-analyst',
            ],
            [
                'company_name'     => 'Studio Kreatif Arek Suroboyo',
                'job_title'        => 'Graphic & UI/UX Design Intern',
                'location'         => 'Surabaya Pusat (Basuki Rahmat)',
                'major_category'   => 'DKV',
                'stipend_type'     => 'allowance',
                'salary_range'     => 'Rp 2.000.000 + Transport / bulan',
                'job_requirements' => "Mahasiswa Desain Komunikasi Visual (DKV), Desain Grafis, atau Multimedia.\nKeahlian wajib: Figma, Adobe Illustrator, Adobe Photoshop, Tipografi, Branding, Social Media Layout.\nMenyertakan link portofolio karya kreatif (Behance / Dribbble / PDF).\nMampu bekerja sesuai deadline dan komunikatif.",
                'application_link' => 'https://areksuroboyo.studio/career/design-intern',
            ],
            [
                'company_name'     => 'PT Maspion Group Indonesia',
                'job_title'        => 'Accounting & Corporate Tax Intern',
                'location'         => 'Surabaya Selatan (Wonokromo / Ahmad Yani)',
                'major_category'   => 'Akuntansi/Keuangan',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 2.500.000 / bulan',
                'job_requirements' => "Mahasiswa aktif D3/S1 Akuntansi atau Perpajakan.\nKeahlian wajib: Jurnal Akuntansi Umum, Buku Besar, Penyusunan Laporan Keuangan, e-Faktur, PPh 21/23, Excel Advanced.\nTeliti, disiplin terhadap arsip dokumen keuangan, dan jujur.",
                'application_link' => 'https://maspion.com/careers/accounting-intern-surabaya',
            ],
            [
                'company_name'     => 'CV Jatim E-Commerce Jaya',
                'job_title'        => 'Social Media Specialist & Content Creator Intern',
                'location'         => 'Surabaya Timur (Gubeng / Dharmawangsa)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'allowance',
                'salary_range'     => 'Rp 2.200.000 / bulan',
                'job_requirements' => "Mahasiswa Ilmu Komunikasi, Pemasaran, Sastra, atau Penyiaran.\nKeahlian wajib: Manajemen Akun Instagram & TikTok, Copywriting Menarik, Pengambilan Video Smartphone, Editing CapCut/Canva, Analisis Tren FYP.\nPercaya diri di depan kamera dan memiliki inisiatif kreatif tinggi.",
                'application_link' => 'https://jatimecommerce.co.id/jobs/sosmed-intern',
            ],
            [
                'company_name'     => 'PT Petrokimia Inovasi Teknologi',
                'job_title'        => 'Electrical Automation & PLC Engineer Intern',
                'location'         => 'Surabaya Barat / Gresik',
                'major_category'   => 'Teknik Elektro',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 3.000.000 / bulan',
                'job_requirements' => "Mahasiswa Teknik Elektro, Teknik Mekatronika, atau Otomasi Industri.\nKeahlian wajib: PLC Programming (Siemens / Omron), SCADA dasar, Rangkaian Listrik Industri, Pembacaan Single Line Diagram (SLD), Sensor & Aktuator.\nMengutamakan keselamatan kerja (K3) dan ketelitian teknis.",
                'application_link' => 'https://petrotech-inovasi.id/karir/plc-intern',
            ],
            [
                'company_name'     => 'PT Jawa Pos Media Digital',
                'job_title'        => 'SEO Content Writer & Digital Copywriter Intern',
                'location'         => 'Surabaya Selatan (Graha Pena Ahmad Yani)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 2.300.000 / bulan',
                'job_requirements' => "Mahasiswa Sastra Indonesia, Ilmu Komunikasi, Jurnalistik, atau Bahasa Inggris.\nKeahlian wajib: Artikel SEO-Friendly, Keyword Research (Ahrefs/Ubersuggest), WordPress CMS, On-Page SEO, Proofreading.\nMampu menulis minimal 3-4 artikel berkualitas per hari dengan orisinalitas tinggi.",
                'application_link' => 'https://jawapos.com/karir/writer-intern',
            ],
            [
                'company_name'     => 'Arek Logistics & Supply Chain Solution',
                'job_title'        => 'Supply Chain & Operations Intern',
                'location'         => 'Surabaya Utara (Perak / Tanjung Perak)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 2.500.000 / bulan',
                'job_requirements' => "Mahasiswa Teknik Industri, Manajemen Logistik, atau Manajemen Operasi.\nKeahlian wajib: Inventory Management, Vendor Coordination, Warehouse Management System (WMS), Microsoft Excel, Optimasi Rute Pengiriman.\nTanggap, cekatan, dan mampu berkoordinasi di lapangan pergudangan.",
                'application_link' => 'https://areklogistics.id/career/ops-intern',
            ],
            [
                'company_name'     => 'PT Kencana Baja Indonesia',
                'job_title'        => 'HR & Talent Acquisition Operations Intern',
                'location'         => 'Surabaya Barat (Tandes)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'allowance',
                'salary_range'     => 'Rp 2.000.000 / bulan',
                'job_requirements' => "Mahasiswa Psikologi, Manajemen SDM, atau Hukum.\nKeahlian wajib: Screening CV, Penjadwalan Interview, Administrasi HR, Pengelolaan Job Portal (Jobstreet/LinkedIn), Komunikasi Interpersonal.\nEmpati tinggi, ramah, dan tertib administrasi data karyawan.",
                'application_link' => 'https://kencanabaja.co.id/jobs/hr-intern',
            ],
            [
                'company_name'     => 'Surabaya HealthTech Solutions',
                'job_title'        => 'Healthcare Software & Data Support Intern',
                'location'         => 'Surabaya Timur (Kertajaya)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'Rp 2.800.000 / bulan',
                'job_requirements' => "Mahasiswa Sistem Informasi Kesehatan, Informatika Medis, atau Teknik Informatika.\nKeahlian wajib: SQL Database, Electronic Medical Record (EMR) Support, User Training, Troubleshooting Hardware/Software, REST API.\nPeduli pada standard privasi data rekam medis pasien.",
                'application_link' => 'https://sbyhealthtech.id/karir/internship',
            ],

            // ==========================================
            // REMOTE / LUAR NEGERI (10 Lowongan)
            // ==========================================
            [
                'company_name'     => 'ByteDance Singapore',
                'job_title'        => 'Machine Learning & NLP Research Intern',
                'location'         => 'Remote - Singapore',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'SGD 1,800 - 2,500 / month',
                'job_requirements' => "Undergraduate or Master student in Computer Science, AI, or Computational Linguistics.\nKey skills required: Python, PyTorch, Transformers, LLM fine-tuning, Natural Language Processing (NLP), Git, Linux.\nFluent in English (written & spoken). High passion for recommendation algorithms and multimodal AI.",
                'application_link' => 'https://jobs.bytedance.com/en/position/singapore-nlp-intern',
            ],
            [
                'company_name'     => 'Grab Singapore',
                'job_title'        => 'Fullstack Software Engineer Intern (Go + React)',
                'location'         => 'Remote - Singapore',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'SGD 1,500 - 2,200 / month',
                'job_requirements' => "Student in Computer Science or Software Engineering.\nKey skills required: Go (Golang), React.js, TypeScript, PostgreSQL, REST/gRPC API, Docker, Unit Testing, Git.\nExperience building scalable cloud web applications and collaborative remote working.",
                'application_link' => 'https://grab.careers/jobs/intern-fullstack-sg',
            ],
            [
                'company_name'     => 'Canva Sydney',
                'job_title'        => 'Product Design (UI/UX) Intern',
                'location'         => 'Remote - Australia (Sydney)',
                'major_category'   => 'DKV',
                'stipend_type'     => 'paid',
                'salary_range'     => 'AUD 2,200 / month',
                'job_requirements' => "Enrolled in Visual Communication, Interaction Design, Human-Centered Design, or Fine Arts.\nKey skills required: Figma, Design Systems, Rapid Prototyping, User Experience Research, Accessibility (a11y), Visual Hierarchy.\nOutstanding design portfolio showcasing intuitive software interfaces.",
                'application_link' => 'https://www.canva.com/careers/jobs/product-design-intern',
            ],
            [
                'company_name'     => 'Rakuten Tokyo',
                'job_title'        => 'Cloud Platform & DevOps Engineer Intern',
                'location'         => 'Remote - Japan (Tokyo)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'JPY 180,000 / month',
                'job_requirements' => "University student in IT, Computer Engineering, or Cloud Infrastructure.\nKey skills required: Linux Administration, Docker, Kubernetes, CI/CD pipelines (GitHub Actions), AWS / GCP, Python / Bash scripting.\nEnglish working proficiency (Japanese language is NOT mandatory).",
                'application_link' => 'https://rakuten.careers/jobs/cloud-intern-tokyo',
            ],
            [
                'company_name'     => 'Delivery Hero SE Berlin',
                'job_title'        => 'Global Business Strategy & Operations Intern',
                'location'         => 'Remote - Europe (Berlin)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'paid',
                'salary_range'     => 'EUR 1,200 / month',
                'job_requirements' => "Student pursuing Business Administration, International Economics, or Supply Chain Management.\nKey skills required: Market Sizing, Financial Modeling, KPI Tracking, Advanced Google Sheets / Excel, Pitch Decks (Keynote/Slides).\nSelf-starter attitude with excellent asynchronous remote communication skills.",
                'application_link' => 'https://careers.deliveryhero.com/jobs/business-intern-remote',
            ],
            [
                'company_name'     => 'Automattic (WordPress.com)',
                'job_title'        => 'Remote Content & Community Strategist Intern',
                'location'         => 'Remote - Global / US',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'paid',
                'salary_range'     => 'USD 1,500 / month',
                'job_requirements' => "Passionate about open web, blogging, and developer communities.\nKey skills required: Native/fluent English copywriting, Community Moderation, Social Media Management, WordPress Publishing, SEO Basics.\n100% remote asynchronous mindset, high personal autonomy, and discipline.",
                'application_link' => 'https://automattic.com/work-with-us/internships',
            ],
            [
                'company_name'     => 'Stripe Asia Pacific',
                'job_title'        => 'Financial Risk & Data Compliance Intern',
                'location'         => 'Remote - Singapore',
                'major_category'   => 'Akuntansi/Keuangan',
                'stipend_type'     => 'paid',
                'salary_range'     => 'SGD 2,000 / month',
                'job_requirements' => "Majoring in Finance, Accounting, Actuarial Science, or Risk Management.\nKey skills required: Financial Data Analysis, SQL, Anti-Money Laundering (AML) fundamentals, Fraud Detection Concept, Excel Modeling.\nStrong ethical integrity and analytical rigor.",
                'application_link' => 'https://stripe.com/jobs/financial-compliance-intern',
            ],
            [
                'company_name'     => 'Atlassian Australia',
                'job_title'        => 'QA Automation & Test Engineering Intern',
                'location'         => 'Remote - Australia (Sydney)',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'AUD 2,000 / month',
                'job_requirements' => "Computer Science or Software Engineering student.\nKey skills required: Cypress or Playwright, JavaScript/TypeScript, REST API Testing, Jira & Confluence workflow, Git.\nPassionate about building bulletproof automated test suites for developer productivity tools.",
                'application_link' => 'https://www.atlassian.com/company/careers/internships',
            ],
            [
                'company_name'     => 'GitLab Inc.',
                'job_title'        => 'Open Source Developer Advocate Intern',
                'location'         => 'Remote - Global / US',
                'major_category'   => 'Informatika/SI',
                'stipend_type'     => 'paid',
                'salary_range'     => 'USD 1,800 / month',
                'job_requirements' => "Active contributor to open-source software with solid Git knowledge.\nKey skills required: Git, Ruby / Go / Python, Markdown Documentation, Public Speaking / Screencasting, CI/CD pipeline setup.\nExcellent communication skills in an all-remote global company culture.",
                'application_link' => 'https://about.gitlab.com/jobs/dev-advocate-intern',
            ],
            [
                'company_name'     => 'Wise (formerly TransferWise)',
                'job_title'        => 'Growth Marketing & Analytics Intern',
                'location'         => 'Remote - Europe (London)',
                'major_category'   => 'Manajemen/Pemasaran',
                'stipend_type'     => 'paid',
                'salary_range'     => 'GBP 1,300 / month',
                'job_requirements' => "Student in Marketing Analytics, Business, or Economics.\nKey skills required: A/B Testing, Funnel Analytics, Google Analytics 4, SQL fundamentals, Creative Copywriting, Customer Acquisition Cost (CAC) understanding.\nData-driven mindset with obsession for financial transparency.",
                'application_link' => 'https://www.wise.jobs/jobs/growth-marketing-intern-remote',
            ],
        ];
    }
}
