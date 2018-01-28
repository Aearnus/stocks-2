function init() {
    funnyName();
    verifyLogin(function (status) {
        if (!status) {
            alert("There was a problem with your login token! You will be redirected back to the login page.");
            window.location.href = "/";
        }
    });
    i("createStockUserId").value = localStorage.getItem("stocks2id");
    updateUserInfo();
    createExampleStocks();
}
function createExampleStocks() {
    i("stockList").appendChild(i("stockTickerSmallFragment").content);
}
function updateUserInfo() {
    getRequest("/idinfo/" + localStorage.getItem("stocks2id"), function (req) {
        console.log(req.responseText);
        var jsonResponse = JSON.parse(req.responseText);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the user information! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            i("money").innerHTML = jsonResponse["data"]["money"];
            var totalValue = jsonResponse["data"]["money"];
            for (var stockName in jsonResponse["data"]["ownedStocks"]) {
                // TODO: multiply this by the stock value
                totalValue += jsonResponse["data"]["ownedStocks"][stockName]["shares"]
            }
            i("totalValue").innerHTML = totalValue;
        }
    });
}
