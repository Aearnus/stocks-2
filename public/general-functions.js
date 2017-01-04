function i(id) { return document.getElementById(id); }

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
        "Tell Me My Odds"
    ]
    var finalName = nameArray[Math.floor(Math.random() * nameArray.length)];
    document.title = "Stocks 2: " + finalName;
    i("gameSubtitle").innerHTML = finalName;
}
