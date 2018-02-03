function init() {
    funnyName();
    updateStock();
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
            // TODO
        }
    }
}

function buyStock(uuid, event) {

}

function sellStock(amount, value) {

}

function createTransactionView(time, shares, shareValue, uuid) {
    console.log("Creating transaction view for transaction " + uuid);
    var template = i("transactionTemplate").cloneNode(true).content;
    template.querySelector(".transactionTime").textContent = Math.floor(Date.now()/1000) - time ;
    template.querySelector(".transactionInfo > span")[0].textContent = shares;
    template.querySelector(".transactionInfo > span")[1].textContent = value;
    template.querySelector(".transactionPrice").textContent = shares * value;
    template.querySelector(".transactionBuy").onclick = function (e) { buyStock(uuid, e); }
    return template;
}
