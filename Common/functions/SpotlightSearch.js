// Shared catalog for preference validation, settings and URL construction.
var engines = [
    {
        "id": "google",
        "label": "Google",
        "url": "https://www.google.com/search?q="
    },
    {
        "id": "bing",
        "label": "Bing",
        "url": "https://www.bing.com/search?q="
    },
    {
        "id": "duckduckgo",
        "label": "DuckDuckGo",
        "url": "https://duckduckgo.com/?q="
    },
    {
        "id": "yahoo",
        "label": "Yahoo",
        "url": "https://search.yahoo.com/search?p="
    },
    {
        "id": "baidu",
        "label": "百度",
        "url": "https://www.baidu.com/s?wd="
    },
    {
        "id": "yandex",
        "label": "Yandex",
        "url": "https://yandex.com/search/?text="
    },
    {
        "id": "brave",
        "label": "Brave Search",
        "url": "https://search.brave.com/search?q="
    },
    {
        "id": "startpage",
        "label": "Startpage",
        "url": "https://www.startpage.com/sp/search?query="
    },
    {
        "id": "ecosia",
        "label": "Ecosia",
        "url": "https://www.ecosia.org/search?q="
    },
    {
        "id": "qwant",
        "label": "Qwant",
        "url": "https://www.qwant.com/?q="
    },
    {
        "id": "naver",
        "label": "Naver",
        "url": "https://search.naver.com/search.naver?query="
    },
    {
        "id": "yahoo-japan",
        "label": "Yahoo! Japan",
        "url": "https://search.yahoo.co.jp/search?p="
    },
    {
        "id": "sogou",
        "label": "搜狗",
        "url": "https://www.sogou.com/web?query="
    },
    {
        "id": "360",
        "label": "360 搜索",
        "url": "https://www.so.com/s?q="
    },
    {
        "id": "seznam",
        "label": "Seznam",
        "url": "https://search.seznam.cz/?q="
    },
    {
        "id": "daum",
        "label": "Daum",
        "url": "https://search.daum.net/search?q="
    },
    {
        "id": "coccoc",
        "label": "Cốc Cốc",
        "url": "https://coccoc.com/search?query="
    }
];

function engineFor(value) {
    return engines.find(function(engine) { return engine.id === value; }) || engines[0];
}

function normalizedEngine(value) {
    return engineFor(String(value || "")).id;
}

function searchUrl(engineId, query) {
    var value = String(query || "").trim();
    return value ? engineFor(engineId).url + encodeURIComponent(value) : "";
}
