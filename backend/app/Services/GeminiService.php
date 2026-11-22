<?php

namespace App\Services;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Klien REST untuk Google Gemini API (generateContent).
 * Konfigurasi lewat .env: GEMINI_API_KEY dan (opsional) GEMINI_MODEL.
 */
class GeminiService
{
    private const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/';

    /** Jawaban teks bebas. */
    public function text(string $system, string $prompt, float $temperature = 0.7): string
    {
        return $this->call($system, $prompt, ['temperature' => $temperature]);
    }

    /** Jawaban terstruktur (JSON) -> array. */
    public function json(string $system, string $prompt, float $temperature = 0.4): array
    {
        $raw = $this->call($system, $prompt, [
            'temperature'      => $temperature,
            'responseMimeType' => 'application/json',
        ]);

        return $this->parseJson($raw);
    }

    private function call(string $system, string $prompt, array $config): string
    {
        $key = (string) env('GEMINI_API_KEY', '');
        if ($key === '') {
            throw new GeminiException('GEMINI_API_KEY belum diisi di file .env backend.');
        }

        $model  = (string) env('GEMINI_MODEL', 'gemini-2.5-flash');
        $verify = filter_var(env('HTTP_VERIFY_SSL', true), FILTER_VALIDATE_BOOLEAN);

        $payload = [
            'systemInstruction' => ['parts' => [['text' => $system]]],
            'contents'          => [['role' => 'user', 'parts' => [['text' => $prompt]]]],
            'generationConfig'  => $config + ['maxOutputTokens' => 8192],
        ];

        $response = null;
        for ($attempt = 1; $attempt <= 2; $attempt++) {
            try {
                $response = Http::withoutVerifying()
                    ->withOptions([
                        'curl' => [
                            CURLOPT_IPRESOLVE => CURL_IPRESOLVE_V4,
                        ],
                    ])
                    ->timeout(12)
                    ->withHeaders(['x-goog-api-key' => $key])
                    ->acceptJson()
                    ->asJson()
                    ->post(self::ENDPOINT . $model . ':generateContent', $payload);
            } catch (\Throwable $e) {
                Log::warning('Gemini koneksi gagal: ' . $e->getMessage());
                throw new GeminiException('Tidak dapat menghubungi Gemini. Periksa koneksi internet laptop Anda.');
            }

            // 503 = server sibuk, coba sekali lagi.
            if ($response->status() !== 503 || $attempt === 2) {
                break;
            }
            usleep(1500000);
        }

        if (! $response->successful()) {
            throw $this->httpError($response, $model);
        }

        $parts = $response->json('candidates.0.content.parts', []);
        $text  = collect($parts)
            ->reject(fn ($p) => ! empty($p['thought']))
            ->pluck('text')
            ->implode('');

        if (trim($text) === '') {
            $reason = $response->json('candidates.0.finishReason')
                ?? $response->json('promptFeedback.blockReason');
            throw new GeminiException(
                'AI tidak mengembalikan jawaban' . ($reason ? " ({$reason})" : '') . '. Coba lagi.'
            );
        }

        return trim($text);
    }

    private function httpError(Response $response, string $model): GeminiException
    {
        $status  = $response->status();
        $message = (string) $response->json('error.message', '');
        Log::warning("Gemini HTTP {$status}: {$message}");

        if ($status === 429) {
            return new GeminiException('Kuota Gemini sedang habis atau terlalu banyak permintaan. Tunggu sekitar satu menit lalu coba lagi.');
        }
        if ($status === 404) {
            return new GeminiException("Model '{$model}' tidak ditemukan untuk akun Anda. Ganti GEMINI_MODEL di .env dengan model yang tersedia di Google AI Studio.");
        }
        if ($status === 400 && stripos($message, 'api key') !== false) {
            return new GeminiException('GEMINI_API_KEY tidak valid. Periksa kembali di file .env.');
        }
        if ($status === 401 || $status === 403) {
            return new GeminiException('API key Gemini ditolak (tidak valid atau tidak punya izin).');
        }
        if ($status === 503) {
            return new GeminiException('Server Gemini sedang sibuk. Coba lagi beberapa saat.');
        }

        return new GeminiException('Gemini error (' . $status . '): ' . mb_substr($message, 0, 160));
    }

    private function parseJson(string $raw): array
    {
        $clean = trim(preg_replace('/^```(?:json)?\s*|\s*```$/i', '', trim($raw)));
        $data  = json_decode($clean, true);

        if (! is_array($data)) {
            $start = strpos($clean, '{');
            $end   = strrpos($clean, '}');
            if ($start !== false && $end !== false && $end > $start) {
                $data = json_decode(substr($clean, $start, $end - $start + 1), true);
            }
        }

        if (! is_array($data)) {
            throw new GeminiException('Respons AI tidak valid. Coba lagi.');
        }

        return $data;
    }
}
