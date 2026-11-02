<?php
$credentials = json_decode(file_get_contents('/fixtures/credentials.json'), true, 512, JSON_THROW_ON_ERROR);
$prefix = getenv('BUSYMAX_BAIKAL_BASE_URI') ?: '/';
$context = stream_context_create(['http' => ['method' => 'PROPFIND', 'timeout' => 5,
    'header' => "Depth: 0\r\nAuthorization: Basic " . base64_encode('alice:' . $credentials['alice']) . "\r\n",
    'content' => '<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>']]);
$body = @file_get_contents('http://127.0.0.1' . $prefix . 'dav.php/', false, $context);
exit($body !== false && str_contains($http_response_header[0], '207') && str_contains($body, 'current-user-principal') ? 0 : 1);
