function init() {
    funnyName();
    updateStock();
    createHistoryGraph(i("stockHistoryGraph"), stock["history"]);
    // TODO: create document.user
}

function updateStock() {
    i("stockName").textContent = stock["name"];
    i("stockDesc").textContent = stock["desc"];
    i("stockValue").textContent = stock["averageValue"];
    i("valueChange").textContent = stockHistoryToChange(stock);
    for (var index in stock["history"]) {
        var trans = stock["history"][index];
        if (trans["transaction"] == "sell") {
            i("sellOrders").appendChild(createSellView(trans["time"], trans["amount"], trans["value"], trans["uuid"]));
        } else if (trans["transaction"] == "buy") {
            i("buyOrders").appendChild(createBuyView(trans["time"], trans["amount"], trans["value"], trans["uuid"]));
        }
    }
}

function updateBuyStock() {
    if (i("buyPrice").value =< 0) {
        i("buyPrice").value = 1;
    }
    if (i("buyAmount").value =< 0) {
        i("buyAmount").value = 1;
    }
    var totalValue = i("buyPrice").value * i("buyAmount").value;
    i("buyValue").value = totalValue;
    if (totalValue > user["money"]) {

    }
}
function buyStock() {
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
    }
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
