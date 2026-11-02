<?php
// First-party deployment provisioning. Upstream source and vendor files stay intact.
require '/var/www/baikal/vendor/autoload.php';

$root = '/var/www/baikal';
$credentials = json_decode(file_get_contents('/fixtures/credentials.json'), true, 512, JSON_THROW_ON_ERROR);
if (!file_exists("$root/Specific/db/db.sqlite")) {
    @mkdir("$root/Specific/db", 0750, true);
    @unlink("$root/Specific/db/initializing.sqlite");
    $db = new PDO("sqlite:$root/Specific/db/initializing.sqlite");
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $db->exec(file_get_contents("$root/Core/Resources/Db/SQLite/db.sql"));
    $calendars = new Sabre\CalDAV\Backend\PDO($db);
    $users = $db->prepare('INSERT INTO users (username, digesta1) VALUES (?, ?)');
    $principals = $db->prepare('INSERT INTO principals (uri, email, displayname) VALUES (?, ?, ?)');
    foreach ($credentials as $user => $password) {
        $users->execute([$user, md5("$user:BaikalDAV:$password")]);
        $principals->execute(["principals/$user", "$user@example.test", "BusyMax QA $user"]);
        foreach (['calendar-proxy-read', 'calendar-proxy-write'] as $proxy) {
            $principals->execute(["principals/$user/$proxy", null, null]);
        }
        foreach (['events' => ['VEVENT'], 'tasks' => ['VTODO'], 'mixed' => ['VEVENT', 'VTODO']] as $slug => $components) {
            $calendars->createCalendar("principals/$user", $slug, [
                '{DAV:}displayname' => "BusyMax QA $slug",
                '{urn:ietf:params:xml:ns:caldav}supported-calendar-component-set' =>
                    new Sabre\CalDAV\Xml\Property\SupportedCalendarComponentSet($components),
            ]);
        }
    }
    // A separate calendar owned by bob and shared read-only to alice.
    $ids = $calendars->createCalendar('principals/bob', 'restricted', [
        '{DAV:}displayname' => 'BusyMax QA read only',
    ]);
    $insert = $db->prepare('INSERT INTO calendarinstances (calendarid, principaluri, access, displayname, uri, share_invitestatus) VALUES (?, ?, ?, ?, ?, 2)');
    $insert->execute([$ids[0], 'principals/alice', Sabre\DAV\Sharing\Plugin::ACCESS_READ, 'Read only', 'restricted']);
    $db = null;
    rename("$root/Specific/db/initializing.sqlite", "$root/Specific/db/db.sqlite");
}
if (!file_exists("$root/config/baikal.yaml")) {
    $config = [
        'system' => [
            'configured_version' => '0.12.1', 'timezone' => 'UTC',
            'card_enabled' => false, 'cal_enabled' => true,
            'dav_auth_type' => 'Basic', 'auth_realm' => 'BaikalDAV',
            'admin_passwordhash' => password_hash(bin2hex(random_bytes(32)), PASSWORD_DEFAULT),
            'failed_access_message' => 'QA authentication failed',
            'base_uri' => getenv('BUSYMAX_BAIKAL_BASE_URI') ?: '', 'invite_from' => '',
        ],
        'database' => [
            'backend' => 'sqlite', 'sqlite_file' => "$root/Specific/db/db.sqlite",
            'encryption_key' => bin2hex(random_bytes(32)),
        ],
    ];
    file_put_contents("$root/config/baikal.yaml", Symfony\Component\Yaml\Yaml::dump($config, 4));
    file_put_contents("$root/Specific/INSTALL_DISABLED", '');
}
