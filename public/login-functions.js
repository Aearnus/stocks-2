GLOBALIP = "10.0.1.22"

function init() {
    funnyName();
}

function getId() {
    getRequest("/newId", function (req) {
        i("yourId").innerHTML = JSON.parse(req.responseText)["id"];
    });
}

function storeId() {
    localStorage.setItem("stocks2id", i("idEntry").value);
}
