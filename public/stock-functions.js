function init() {
    funnyName();
    i("stockName").textContent = stock["name"];
    i("stockDesc").textContent = stock["desc"];
    i("stockValue").textContent = stock["averageValue"];
    i("valueChange").textContent = stockHistoryToChange(stock);
}
