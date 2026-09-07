var loggedInUser;
var UserLoggedId;
var userRole;

(function checkSession() {
    var cookies = decodeURIComponent(document.cookie);
    var sessionCookie = cookies.split('; ').find(function(row) {
        return row.startsWith('sessionObject=');
    });

    function redirectToLogin() {
        var redirect = encodeURIComponent(window.location.href);
        window.location.href = '/login.html?redirect=' + redirect;
    }

    if (sessionCookie) {
        try {
            var sessionData = JSON.parse(sessionCookie.split('=')[1]);
            loggedInUser = sessionData.username;
            UserLoggedId = sessionData.userId;
            userRole = sessionData.role || 'user';
        } catch (e) {
            redirectToLogin();
            return;
        }
    } else {
        redirectToLogin();
        return;
    }
    // Track activity
    var page = location.pathname.split('/').pop() || 'index.html';
    var xhr = new XMLHttpRequest();
    xhr.open('POST', '/menu_beta/users_api.php', true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.send('action=activity&userId=' + encodeURIComponent(UserLoggedId) + '&page=' + encodeURIComponent(page));
})();
