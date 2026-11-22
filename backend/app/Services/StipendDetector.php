<?php

namespace App\Services;

/**
 * Deteksi otomatis jenis stipend (paid / unpaid / allowance / unknown)
 * dari teks lowongan menggunakan regex.
 */
class StipendDetector
{
    public static function detect(?string $salary, ?string $text = ''): string
    {
        $salary = trim((string) $salary);
        $text   = mb_strtolower((string) $text);

        // 1. Pernyataan eksplisit "tidak dibayar"
        if (preg_match('/\b(unpaid|volunteer|tanpa (gaji|bayaran)|no (pay|compensation)|for (course )?credit|credit only)\b/u', $text)) {
            return 'unpaid';
        }

        // 2. Ada kolom gaji/salary yang terisi
        if ($salary !== '') {
            return 'paid';
        }

        // 3. Uang saku / tunjangan
        if (preg_match('/\b(allowance|uang saku|uang makan|uang transport|transport allowance|meal allowance)\b/u', $text)) {
            return 'allowance';
        }

        // 4. Indikasi dibayar: simbol mata uang + angka, "10k", "paid", "stipend", dst.
        if (preg_match('/(\$|€|£|rp\.?)\s?\d|\b\d+\s?(k|rb|juta)\b|\b(usd|eur|idr)\b|\b(paid|stipend|salary|gaji|compensation|honorarium)\b/u', $text)) {
            return 'paid';
        }

        return 'unknown';
    }
}
