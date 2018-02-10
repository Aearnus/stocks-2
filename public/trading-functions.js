var user = {}

function init() {
    funnyName();
    verifyLogin(function (status) {
        if (!status) {
            alert("There was a problem with your login token! You will be redirected back to the login page.");
            window.location.href = "/";
        }
    });
    updateUserInfo();
    populateStockList();
    i("stockSearch").addEventListener("keydown",function(e){if (e.keyCode == 13) { stockSearch(); }});
    i("createStockName").value = "";
    i("createStockName").addEventListener("keydown", function(e){submitCreateStock(e)});
    i("createStockDesc").value = "";
    i("createStockDesc").addEventListener("keydown", function(e){submitCreateStock(e)});
    i("createStockAmount").value = "";
    i("createStockAmount").addEventListener("keydown", function(e){submitCreateStock(e)});
}

function createSmallStockTicker(stockName, stockValue, stockChange) {
    console.log("Creating small stock ticker for stock " + stockName);
    var template = i("stockTickerSmallTemplate").cloneNode(true).content;
    template.querySelector("a").href = "stock/" + stockName;
    template.querySelector(".stockTitleSmall").textContent = stockName;
    template.querySelector(".stockValueTickerSmall").textContent = stockValue;
    template.querySelector(".stockChangeTickerSmall").textContent = stockChange;
    template.querySelector(".stockChangeTickerSmall").classList.add(stockChange > 0 ? "positiveChange" : "negativeChange");
    return template;
}
function createLargeStockTicker(stockName, amountOwned, parentNode) {
    console.log("Creating large stock ticker for stock " + stockName);
    // default values for the ticker, then the ticker itself
    var stockChange = 100;
    var stockValue = 100;
    var stockDescription = "DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION DESCRIPTION";
    var templateFragment = i("stockTickerLargeTemplate").cloneNode(true).content;
    parentNode.appendChild(templateFragment);
    var template = parentNode.lastChild;
    getRequest("/stockinfo/" + stockName, function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the stock info for a large ticker! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            var stock = jsonResponse["data"];
            stockValue = stock["averageValue"];
            stockDescription = stock["desc"];
            stockChange = stockHistoryToChange(stock);
            template.href = "/stock/" + stockName;
            template.querySelector(".stockTitleLarge").textContent = stockName;
            template.querySelector(".stockValueTickerLarge").textContent = stockValue;
            template.querySelector(".stockChangeTickerLarge").textContent = stockChange;
            template.querySelector(".stockChangeTickerLarge").classList.add(stockChange > 0 ? "positiveChange" : "negativeChange");
            if (amountOwned > 0) {
                template.querySelector(".stockOwnedTickerLarge").textContent = amountOwned;
            } else {
                template.querySelector(".stockOwnedTickerLarge").remove();
            }
            template.querySelector(".stockDescriptionTickerLarge").textContent = stockDescription;
            createHistoryGraph(template.querySelector(".stockGraph"), stock["history"]);
        }
    });
    return template;
}
function populateStockList() {
    emptyNode(i("topStockList"));
    emptyNode(i("newStockList"));
    // first, populate the top stocks list
    getRequest("/liststocks?criteria=top&n=10", function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the stock listings! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            for (var stockIndex in jsonResponse["data"]) {
                var stock = jsonResponse["data"][stockIndex];
                i("topStockList").appendChild(createSmallStockTicker(stock["name"], stock["averageValue"], stockHistoryToChange(stock)));
            }
        }
    });
    // then, populate the new stocks list
    getRequest("/liststocks?criteria=new&n=10", function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the stock listings! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            for (var stockIndex in jsonResponse["data"]) {
                var stock = jsonResponse["data"][stockIndex];
                i("newStockList").appendChild(createSmallStockTicker(stock["name"], stock["averageValue"], stockHistoryToChange(stock)));
            }
        }
    });
}
function updateUserInfo() {
    emptyNode(i("ownedStockList"));
    emptyNode(i("createdStockList"));
    getRequest("/idinfo/" + localStorage.getItem("stocks2id"), function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        console.log(jsonResponse);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the user information! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            user = jsonResponse["data"];
            i("money").textContent = user["money"];
            var totalValue = user["money"];
            for (var stockIndex in user["ownedStocks"]) {
                var stockName = user["ownedStocks"][stockIndex]["name"];
                var amountOwned = user["ownedStocks"][stockIndex]["shares"];
                // TODO: multiply this by the stock value
                totalValue += amountOwned; // * stockValue;
                createLargeStockTicker(stockName, amountOwned, i("ownedStockList"));
            }
            for (var stockIndex in user["createdStocks"]) {
                var stockName = user["createdStocks"][stockIndex];
                createLargeStockTicker(stockName, 0, i("createdStockList"));
            }
            i("totalValue").textContent = totalValue;
        }
    });
}

function stockSearch() {
    console.log("redirecting to: " + "/stock/" + i("stockSearch").value.toUpperCase());
    window.location.href = "/stock/" + i("stockSearch").value.toUpperCase();
}

function updateCreateStock() {
    var button = i("createStockSubmit");
    var disableButton = [];

    var stockName = i("createStockName").value;
    var stockNameStatus = i("createStockNameStatus");
    // validate stock name
    if (stockName === "") {
        stockNameStatus.textContent = "The name of the business you wish to create. 1 to 10 alphanumeric characters.";
        stockNameStatus.className = "createStockStatus";
        disableButton.push(true);
    } else {
        stockNameStatus.textContent = "Ok!";
        stockNameStatus.className = "createStockStatus createStockOk";
        disableButton.push(false);
        if (stockName.length > 10) {
            stockNameStatus.textContent = "Stock name must be 10 characters or less.";
            stockNameStatus.className = "createStockStatus createStockError";
            disableButton.push(true);
        } if (!/^[a-z0-9]+$/i.test(stockName)) {
            stockNameStatus.textContent = "Stock name must only contain alphanumeric characters.";
            stockNameStatus.className = "createStockStatus createStockError";
            disableButton.push(true);
        }
    }
    //validate stock description
    var stockDesc = i("createStockDesc").value;
    var stockDescStatus = i("createStockDescStatus");
    if (stockDesc === "") {
        stockDescStatus.textContent = "What does this business entail? 4 to 100 alphanumeric characters.";
        stockDescStatus.className = "createStockStatus";
        disableButton.push(true);
    } else {
        stockDescStatus.textContent = "Ok!";
        stockDescStatus.className = "createStockStatus createStockOk";
        disableButton.push(false);
        if (stockDesc.length > 100) {
            stockDescStatus.textContent = "Stock description must be 100 characters or less.";
            stockDescStatus.className = "createStockStatus createStockError";
            disableButton.push(true);
        } if (stockDesc.length < 4) {
            stockDescStatus.textContent = "Stock description must be at least 4 characters.";
            stockDescStatus.className = "createStockStatus createStockError";
            disableButton.push(true);
        } if (!/^[a-z0-9 ]+$/i.test(stockDesc)) {
            stockDescStatus.textContent = "Stock description must only contain alphanumeric characters or spaces.";
            stockDescStatus.className = "createStockStatus createStockError";
            disableButton.push(true);
        }
    }
    // validate stock amount
    var stockAmount = i("createStockAmount").value;
    var stockAmountStatus = i("createStockAmountStatus");
    if (stockAmount === "") {
        stockAmountStatus.textContent = "How many shares to create? At least 200, at $100 a share.";
        stockAmountStatus.className = "createStockStatus";
        disableButton.push(true);
    } else {
        stockAmountStatus.textContent = "Ok!";
        stockAmountStatus.className = "createStockStatus createStockOk";
        disableButton.push(false);
        if (stockAmount < 200) {
            stockAmountStatus.textContent = "You must create at least 200 shares.";
            stockAmountStatus.className = "createStockStatus createStockError";
            disableButton.push(true);
        }
    }
    // validate cash amount
    var stockValue = i("createStockValue");
    var value = stockAmount * 100
    stockValue.textContent = value
    if (value > user["money"]) {
        stockValue.className = "money createStockStatus createStockError";
    } else {
        stockValue.className = "money createStockStatus createStockOk";
    }
    button.disabled = disableButton.some(x=>x);
}
function submitCreateStock(e) {
    if (e.keyCode == 13) {
        i("createStockSubmit").click();
    }
}
function createStock() {
    if (!i("createStockSubmit").disabled) {
        postRequest(
            "/createstock",
            function(req) {
                console.log(req.responseText);
                updateUserInfo();
                populateStockList();
            },
            JSON.stringify(
                {
                    stockName: i("createStockName").value,
                    stockDesc: i("createStockDesc").value,
                    stockAmount: i("createStockAmount").value,
                    userId: localStorage.getItem("stocks2id")
                }
            )
        );
    }
}
