function createHistoryGraph(canvas, history) {
    var sortedHistory = history.filter((t) => t["transaction"] === "done").sort(function (a,b) {a["time"] - b["time"]});
    console.log("sorted history: " + sortedHistory.toString());
    var formattedHistory = sortedHistory.map((t) => t["value"]);
    console.log("formatted history: " + formattedHistory);

    var ctx = canvas.getContext("2d");
    var historyGraph = new Chart(ctx, {
    type: "line",
    data: {
        datasets: [{
            label: "Stock Value History",
            backgroundColor: "#26cd1e",
            borderColor: "#000",
            data: formattedHistory,
            borderWidth: 2
        }],
        labels: Array(formattedHistory.length).fill(0).map((v,k) => k + 1).reverse()
    },
    options: {
        legend: {
            display: false
        },
        responsive: true,
        maintainAspectRatio: false,
        scales: {
            yAxes: [{
                ticks: {
                    beginAtZero: false
                }
            }],
        }
    }
});
}
