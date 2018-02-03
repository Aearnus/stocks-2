function init() {
    funnyName();
    i("stockName").textContent = stock["name"];
    i("stockDesc").textContent = stock["desc"];
    i("stockValue").textContent = stock["averageValue"];
    i("valueChange").textContent = stockHistoryToChange(stock);
}

function createTransactionView(time, shares, shareValue, uuid) {
    console.log("Creating transaction view for transaction " + uuid);
    var template = i("transactionTemplate").cloneNode(true).content;
    template.querySelector(".transactionTime").textContent = Math.floor(Date.now()/1000) - time ;
    //TODO
}
