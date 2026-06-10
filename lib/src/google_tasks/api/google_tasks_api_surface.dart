const googleTasksReadWriteScope = 'https://www.googleapis.com/auth/tasks';
const googleTasksReadOnlyScope =
    'https://www.googleapis.com/auth/tasks.readonly';
const googleCalendarReadWriteScope = 'https://www.googleapis.com/auth/calendar';
const googleOpenIdScope = 'openid';
const googleEmailScope = 'email';
const googleProfileScope = 'profile';
const googleBusyMaxOAuthScopes = [
  googleOpenIdScope,
  googleEmailScope,
  googleProfileScope,
  googleTasksReadWriteScope,
  googleCalendarReadWriteScope,
];
const googleBusyMaxOAuthScope =
    '$googleOpenIdScope $googleEmailScope $googleProfileScope '
    '$googleTasksReadWriteScope $googleCalendarReadWriteScope';

const implementedGoogleTasksMethods = <String>{
  'tasklists.delete',
  'tasklists.get',
  'tasklists.insert',
  'tasklists.list',
  'tasklists.patch',
  'tasklists.update',
  'tasks.clear',
  'tasks.delete',
  'tasks.get',
  'tasks.insert',
  'tasks.list',
  'tasks.move',
  'tasks.patch',
  'tasks.update',
};
