function init() {
    funnyName();
    verifyLogin(function (status) {
        if (!status) {
            alert("There was a problem with your login token! You will be redirected back to the login page.");
            window.location.href = "/";
        }
    });
    // TODO: create an actual stock creation user interface
    i("createStockUserId").value = localStorage.getItem("stocks2id");
    updateUserInfo();
    populateStockList();
}

function createSmallStockTicker(stockName, stockValue, stockChange) {
    console.log("Creating small stock ticker for stock " + stockName);
    var template = i("stockTickerSmallTemplate").cloneNode(true).content;
    template.querySelector("a").href = "stock/" + stockName;
    template.querySelector(".stockTitleSmall").innerHTML = stockName;
    template.querySelector(".stockValueTickerSmall").innerHTML = stockValue;
    template.querySelector(".stockChangeTickerSmall").innerHTML = stockChange;
    template.querySelector(".stockChangeTickerSmall").classList.add(stockChange > 0 ? "positiveChange" : "negativeChange");
    return template;
}
function createLargeStockTicker(stockName, amountOwned) {
    console.log("Creating large stock ticker for stock " + stockName);
    // TODO: get stock info in this function
    var stockChange = 100;
    var stockValue = 100;
    var stockDescription = "DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION";
    var template = i("stockTickerLargeTemplate").cloneNode(true).content;
    template.querySelector("a").href = "stock/" + stockName;
    template.querySelector(".stockTitleLarge").innerHTML = stockName;
    template.querySelector(".stockValueTickerLarge").innerHTML = stockValue;
    template.querySelector(".stockChangeTickerLarge").innerHTML = stockChange;
    template.querySelector(".stockChangeTickerLarge").classList.add(stockChange > 0 ? "positiveChange" : "negativeChange");
    if (amountOwned > 0) {
        template.querySelector(".stockOwnedTickerLarge").innerHTML = amountOwned;
    } else {
        template.querySelector(".stockOwnedTickerLarge").remove();
    }
    template.querySelector(".stockDescriptionTickerLarge").innerHTML = stockDescription;
    return template;
}
function populateStockList() {
    // first, populate the top stocks list
    getRequest("/liststocks?criteria=top&n=10", function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        console.log(jsonResponse);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the stock listings! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            for (var stockIndex in jsonResponse["data"]) {
                var stock = jsonResponse["data"][stockIndex];
                // TODO: CALCULATE STOCK CHANGE
                i("topStockList").appendChild(createSmallStockTicker(stock["name"], stock["averageValue"], 1));
            }
        }
    });
    // then, populate the new stocks list
    getRequest("/liststocks?criteria=new&n=10", function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        console.log(jsonResponse);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the stock listings! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            for (var stockIndex in jsonResponse["data"]) {
                var stock = jsonResponse["data"][stockIndex];
                // TODO: CALCULATE STOCK CHANGE
                i("newStockList").appendChild(createSmallStockTicker(stock["name"], stock["averageValue"], 1));
            }
        }
    });
}
function updateUserInfo() {
    getRequest("/idinfo/" + localStorage.getItem("stocks2id"), function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        console.log(jsonResponse);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the user information! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            i("money").innerHTML = jsonResponse["data"]["money"];
            var totalValue = jsonResponse["data"]["money"];
            for (var stockIndex in jsonResponse["data"]["ownedStocks"]) {
                var stockName = jsonResponse["data"]["ownedStocks"][stockIndex]["name"];
                var amountOwned = jsonResponse["data"]["ownedStocks"][stockIndex]["shares"];
                // TODO: multiply this by the stock value
                totalValue += amountOwned; // * stockValue;
                // TODO: finish this stock display
                i("ownedStockList").appendChild(createLargeStockTicker(stockName, amountOwned));
            }
            for (var stockIndex in jsonResponse["data"]["createdStocks"]) {
                var stockName = jsonResponse["data"]["createdStocks"][stockIndex];
                // TODO: finish this stock display
                i("createdStockList").appendChild(createLargeStockTicker(stockName, 0));
            }
            i("totalValue").innerHTML = totalValue;
        }
    });
}
