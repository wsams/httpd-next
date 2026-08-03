<?php

declare(strict_types=1);

header('Content-Type: text/html; charset=utf-8');

$version = htmlspecialchars(PHP_VERSION, ENT_QUOTES, 'UTF-8');

echo <<<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>httpd-next php</title>
</head>
<body>
  <h1>PHP-FPM is working</h1>
  <p>PHP {$version}</p>
</body>
</html>
HTML;
