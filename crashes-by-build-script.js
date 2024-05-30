var gRegression1, gRegression2;
function regression_choose()
{
  document.body.classList.add("choose");
  document.body.classList.add("choose1");
  document.getElementById("regression-container").className = "choose1";
  document.body.addEventListener("click", choose_clickhandler, true);
}

function branch_table_for_link(link)
{
  var table = link;
  while (table.tagName != "TABLE") {
    table = table.parentNode;
  }
  return table;
}

function choose_clickhandler(event)
{
  let target = event.target;
  if (target.tagName != "A" || target.parentNode.tagName != "TD") {
    return;
  }
  if (event.button != 0) {
    return;
  }

  if (document.body.classList.contains("choose1")) {
    gRegression1 = target;
    document.body.classList.remove("choose1");
    document.body.classList.add("choose2");
    document.getElementById("regression-container").className = "choose2";

    let targetPlatform = target.textContent;
    // Array.from needed for Chromium and Edge but not Gecko
    for (let link of Array.from(branch_table_for_link(target).querySelectorAll("a"))) {
      if (link.textContent == targetPlatform &&
          // don't allow choosing the same build (in either column)
          link.title != target.title) {
        link.classList.add("choose-eligible");
      }
    }
  } else {
    if (!target.classList.contains("choose-eligible")) {
      return;
    }

    gRegression2 = target;
    document.body.classList.remove("choose2");
    document.body.classList.remove("choose");
    document.getElementById("regression-container").className = "found";

    // Array.from needed for Chromium and Edge but not Gecko
    for (let link of Array.from(document.querySelectorAll("a.choose-eligible"))) {
      link.classList.remove("choose-eligible");
    }
  }

  event.preventDefault();
  event.stopPropagation();

  if (gRegression2) {
    document.body.removeEventListener("click", choose_clickhandler, true);

    var table = branch_table_for_link(gRegression1);
    if (branch_table_for_link(gRegression2) != table) {
      console.log("mismatched tables");
      regression_clear();
      return;
    }
    let branch = table.parentNode.id;
    if (branch.substring(0,7) != "branch-") {
      console.log("bad branch id");
      regression_clear();
      return;
    }
    branch = branch.substring(7);
    let url = "https://hg.mozilla.org/";
    if (branch == "mozilla-central") {
      url += "mozilla-central";
    } else if (branch == "mozilla-aurora") {
      url += "releases/mozilla-aurora";
    } else {
      console.log("unknown branch");
      regression_clear();
      return;
    }
    let rev1, rev2, build1, build2;
    try {
      let rev_re = new RegExp("^[0-9]{2}:[0-9]{2}:[0-9]{2}, rev ([0-9a-f]{40})$");
      rev1 = rev_re.exec(gRegression1.title)[1];
      rev2 = rev_re.exec(gRegression2.title)[1];
      let buildid_re = new RegExp("&build_id=([0-9]{14})&");
      build1 = buildid_re.exec(gRegression1.href)[1];
      build2 = buildid_re.exec(gRegression2.href)[1];
    } catch (ex) {
      console.log("bad link data", ex);
      regression_clear();
      return;
    }
    let fromchange, tochange;
    if (build1 > build2) {
      fromchange = rev2;
      tochange = rev1;
    } else {
      fromchange = rev1;
      tochange = rev2;
    }
    url += `/pushloghtml?fromchange=${fromchange}&tochange=${tochange}`;

    let a = document.getElementById("regression-link");
    a.textContent = url;
    a.href = url;
  }
}

function regression_cancel()
{
  document.body.removeEventListener("click", choose_clickhandler, true);
  document.body.classList.remove("choose1");
  document.body.classList.remove("choose2");
  document.body.classList.remove("choose");
  // Array.from needed for Chromium and Edge but not Gecko
  for (let link of Array.from(document.querySelectorAll("a.choose-eligible"))) {
    link.classList.remove("choose-eligible");
  }
  document.getElementById("regression-container").className = "notstarted";
  gRegression1 = null;
  gRegression2 = null;
}

function regression_clear()
{
  document.getElementById("regression-container").className = "notstarted";
  gRegression1 = null;
  gRegression2 = null;
}

function register_listeners()
{
  document.getElementById("regression-start").addEventListener("click", regression_choose);
  document.getElementById("regression-cancel").addEventListener("click", regression_cancel);
  document.getElementById("regression-clear").addEventListener("click", regression_clear);
}

window.addEventListener("load", register_listeners);
