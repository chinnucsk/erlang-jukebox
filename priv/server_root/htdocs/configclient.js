var config = null;

var refresh_timer = null; // will be result of setTimeout below.
function refresh_timer_tick() {
    config.all_roots()
    .addCallback(function (roots)
    {
	update_roots(roots);
	config.current_rescans()
	.addCallback(function (urls)
	{
	    update_rescans(urls);
	    arm_refresh_timer();
	});
    });
}
function arm_refresh_timer() {
    refresh_timer = setTimeout(refresh_timer_tick, 5000);
}

function button(actionfn, text) {
    var b = document.createElement("a");
    b.className = "action-span";
    b.onclick = actionfn;
    b.innerHTML = text;
    return b;
}

function do_add_root() {
    var e = document.getElementById("new_root");
    rescanner_for(e.value)();
    e.value = "";
}

function do_snapshot() {
    config.snapshot();
}

function rescanner_for(url) {
    return function () {
	config.rescan_root(url).addCallback(update_rescans);
    };
}

function deleter_for(url) {
    return function () {
	config.remove_root(url).addCallback(update_roots);
    };
}

function update_roots(urls) {
    var listnode = document.createElement("ul");
    for (var i = 0; i < urls.length; i++) {
	var root = urls[i];
	var itemnode = document.createElement("li");
	itemnode.appendChild(button(rescanner_for(root), "rescan"));
	itemnode.appendChild(document.createTextNode(" "));
	itemnode.appendChild(button(deleter_for(root), "delete"));
	itemnode.appendChild(document.createTextNode(" " + root));
	listnode.appendChild(itemnode);
    }

    var d = document.getElementById("roots");
    d.innerHTML = "";
    d.appendChild(listnode);
}

function update_rescans(urls) {
    var listnode = document.createElement("ul");
    for (var i = 0; i < urls.length; i++) {
	var root = urls[i];
	var itemnode = document.createElement("li");
	itemnode.appendChild(document.createTextNode(root));
	listnode.appendChild(itemnode);
    }

    var d = document.getElementById("rescans");
    d.innerHTML = "";
    d.appendChild(listnode);
}

function initConfigClient() {
    config = new JsonRpcService("/rpc/config", refresh_timer_tick);
}
