function i(id) { return document.getElementById(id); }

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
function postRequest(url, callback, data) {
    var req = new XMLHttpRequest();
    req.open("POST", url);
    req.onreadystatechange = function () {
        if (req.readyState == XMLHttpRequest.DONE && req.status == 200) {
            callback(req);
        } else if (req.readyState == XMLHttpRequest.DONE && req.status != 200) {
            alert("There was a problem contacting the server: request status " + req.status);
        }
    };
    req.send(data);
}

//true for logged in, false for not logged in
function verifyLogin(callback) {
    var idData = new FormData();
    idData.append("userId", localStorage.getItem("stocks2id"));
    postRequest("/verifylogin", function (req) {
        var res = JSON.parse(req.responseText)["result"];
        callback(res);
    }, idData);
}

function funnyName() {
    var nameArray = [
        "Online Shkrelism",
        "The Next Evolution",
        "Actually Wall Street",
        "For Real This Time",
        "Stop Wasting Your Time",
        "Electric Boogaloo",
        "Sell Your Shekels",
        "/r/WallStreetBets",
        "YOLO",
        "The Meme Economy",
        "Is It Worth It?",
        "The Second Stock",
        "Buy Low, Sell High",
        "Buy High, Sell Low",
        "What Is Humanitarianism?",
        "Exploiting Capitalism",
        "Down With Socialism",
        "The Free Market Economy",
        "Laissez-Faire",
        "Tell Me My Odds",
        "Bury Me In My Money",
        "Why Are You Here?",
        "Bitcoin Edition",
        "The Market Crashes Today"
    ]
    var finalName = nameArray[Math.floor(Math.random() * nameArray.length)];
    document.title = "Stocks 2: " + finalName;
    i("gameSubtitle").textContent = finalName;
}

function stockHistoryToChange(stockHistory) {
    // TODO TODO TODO
    // TAKE A STOCK "history" array and translate it into a recent price change
    return 10;
}
