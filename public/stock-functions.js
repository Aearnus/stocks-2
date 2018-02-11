var user = {}

function init() {
    funnyName();
    update();
    createHistoryGraph(i("stockHistoryGraph"), stock["history"]);
    // TODO: create document.user
}
function update() {
    updateStock();
    populateUser();
    i("buyPrice").value = "";
    i("buyAmount").value = "";
    updateBuyStock();
    updateSellStock();
}

function populateUser() {
    getRequest("/idinfo/" + localStorage.getItem("stocks2id"), function (req) {
        var jsonResponse = JSON.parse(req.responseText);
        console.log(jsonResponse);
        if (jsonResponse["result"] == false) {
            alert("There was an issue getting the user information! Error: " + jsonResponse["data"]["error"] + " You will be redirected back to the login page.");
            window.location.href = "/";
        } else {
            user = jsonResponse["data"];
        }
    });
}

function updateStock() {
    i("stockName").textContent = stock["name"];
    i("stockDesc").textContent = stock["desc"];
    i("stockValue").textContent = stock["averageValue"];
    i("valueChange").textContent = stockHistoryToChange(stock);
    emptyNode(i("sellOrders"));
    emptyNode(i("buyOrders"));
    for (var index in stock["history"]) {
        var trans = stock["history"][index];
        if (trans["transaction"] == "sell") {
            i("sellOrders").appendChild(createSellView(trans["time"], trans["amount"], trans["value"], trans["uuid"]));
        } else if (trans["transaction"] == "buy") {
            i("buyOrders").appendChild(createBuyView(trans["time"], trans["amount"], trans["value"], trans["uuid"]));
        }
    }
}

function submitBuyStock(e) {
    if (e.keyCode == 13) {
        i("buySubmit").click();
    }
}
function updateBuyStock() {
    var buyPrice = parseInt(i("buyPrice").value);
    var buyAmount = parseInt(i("buyAmount").value);
    if (!(Number.isNaN(buyPrice) || Number.isNaN(buyAmount))) {
        if (buyPrice <= 0) {
            i("buyPrice").value = 1;
        }
        if (buyAmount <= 0) {
            i("buyAmount").value = 1;
        }
        var totalValue = buyPrice * buyAmount;
        i("buyValue").textContent = totalValue;
        if (totalValue > user["money"]) {
            i("buyValue").className = "money inputStatus inputError";
            i("buySubmit").disabled = true;
        } else {
            i("buyValue").className = "money inputStatus inputOk";
            i("buySubmit").disabled = false;
        }
    } else {
        i("buyValue").textContent = "0";
        i("buyValue").className = "money inputStatus inputError";
        i("buySubmit").disabled = true;
    }
}
function buyStock() {
    console.log("sending " + JSON.stringify({
        stockName: stock["name"],
        shareAmount: i("buyAmount").value,
        sharePrice: i("buyPrice").value,
        userId: localStorage.getItem("stocks2id")
    }));
    if (!i("buySubmit").disabled) {
        postRequest(
            "/buystock",
            function (req) {
                console.log(req.responseText);
            },
            JSON.stringify({
                stockName: stock["name"],
                shareAmount: i("buyAmount").value,
                sharePrice: i("buyPrice").value,
                userId: localStorage.getItem("stocks2id")
            })
        );
        updateStock();
    }
}
function submitSellStock(e) {
    if (e.keyCode == 13) {
        i("sellSubmit").click();
    }
}
function updateSellStock() {

}
function sellStock() {
    if (!i("sellSubmit").disabled) {
        postRequest(
            "/sellstock",
            function (req) {
                console.log(req.responseText);
            },
            JSON.stringify({
                stockName: stock["name"],
                shareAmount: i("buyAmount").value,
                sharePrice: i("buyPrice").value,
                userId: localStorage.getItem("stocks2id")
            })
        );
    }
    update();
}

function fillOrder(uuid, event) {
    postRequest("/fillorder", function (req) {
        console.log(req.responseText);
    }
    , JSON.stringify({stockName: stock["name"], userId: localStorage.getItem("stocks2id"), transactionId: uuid}));
}

function createSellView(time, shares, shareValue, uuid) {
    console.log("Creating transaction view for transaction " + uuid);
    console.log("Variables: " + time + " " + shares + " " + shareValue + " " + uuid);
    var template = i("transactionTemplate").cloneNode(true).content;
    template.querySelector(".transactionType").textContent = "Sell Order";
    template.querySelector(".transactionTime").textContent = (Math.floor(Date.now()/1000) - time) + " seconds ago";
    template.querySelector(".transactionInfo").children[0].textContent = shares;
    template.querySelector(".transactionInfo").children[2].textContent = shareValue;
    template.querySelector(".transactionPrice").textContent = shares * shareValue;
    template.querySelector(".transactionBuy").innerHTML = "Fill Order<br>(Buy Shares)";
    template.querySelector(".transactionBuy").onclick = function (e) { fillOrder(uuid, e); }
    return template;
}

function createBuyView(time, shares, shareValue, uuid) {
    console.log("Creating transaction view for transaction " + uuid);
    var template = i("transactionTemplate").cloneNode(true).content;
    template.querySelector(".transactionType").textContent = "Buy Order";
    template.querySelector(".transactionTime").textContent = (Math.floor(Date.now()/1000) - time) + " seconds ago";
    template.querySelector(".transactionInfo").children[0].textContent = shares;
    template.querySelector(".transactionInfo").children[2].textContent = shareValue;
    template.querySelector(".transactionPrice").textContent = shares * shareValue;
    template.querySelector(".transactionBuy").innerHTML = "Fill Order<br>(Sell Shares)";
    template.querySelector(".transactionBuy").onclick = function (e) { fillOrder(uuid, e); }
    return template;
}
