function init() {
    funnyName();
    verifyLogin(function (status) {
        if (!status) {
            alert("There was a problem with your login token! You will be redirected back to the login page.");
            window.location.href = "/";
        }
    });
}
