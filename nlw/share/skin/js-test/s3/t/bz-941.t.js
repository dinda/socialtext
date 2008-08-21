(function($) {

var t = new Test.Visual();

t.plan(1);

t.beginAsync(step1);

function step1() {
    t.open_iframe("/admin/index.cgi?action=recent_changes", step2);
}

function step2() {
    t.scrollTo(300);

    t.like(
        t.$("table.dataTable tr.oddRow td em a:eq(0)").attr("href"),
        /action=revision_list;page_name=/,
        "Revision links in listview need to href to revision_list action"
    );

    t.endAsync();
}

})(jQuery);
