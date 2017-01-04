GLOBALIP = "10.0.1.22"

function init() {
    funnyName();
}

function getRequest(url, callback) {
    var req = new XMLHttpRequest();
    req.open("GET", url);
    req.onreadystatechange = function () {
        if (req.readyState == XMLHttpRequest.DONE && req.status == 200) {
            callback(req);
        } else if (req.readyState == XMLHttpRequest.DONE && req.status != 200) {
            alert("There was a problem contacting the server: request status " + req.status);
        }
    };
    req.send(null);
}

function getId() {
    getRequest("/newId", function (req) {
        i("yourId").innerHTML = JSON.parse(req.responseText)["id"];
    });
}
