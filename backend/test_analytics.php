<?php

require __DIR__ . '/vendor/autoload.php';
$app = require __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$controller = app(App\Http\Controllers\Api\AnalyticsController::class);

$start = microtime(true);
$res1 = $controller->marketTrends(request());
$dur1 = round((microtime(true) - $start) * 1000, 2);

echo "marketTrends duration: {$dur1} ms\n";
echo "marketTrends response: " . json_encode($res1->getData()) . "\n\n";

$start2 = microtime(true);
$req = request();
$req->setUserResolver(fn() => App\Models\User::first());
$res2 = $controller->skillScarcity($req);
$dur2 = round((microtime(true) - $start2) * 1000, 2);

echo "skillScarcity duration: {$dur2} ms\n";
echo "skillScarcity response: " . json_encode($res2->getData()) . "\n";
