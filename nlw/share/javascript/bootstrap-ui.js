function query_popup(url, width, height, left, top) {
    if (!width) width = 400;
    if (!height) height = 287;
    if (!left) left = 400-width/2;
    if (!top) top = 280-height/2;
    window.open(url, '_blank', 'toolbar=no, location=no, directories=no, status=no, menubar=no, titlebar=no, scrollbars=yes, resizable=yes, width=' + width + ', height=' + height + ', left=' + left + ', top=' + top);
}

jQuery(function () {
    if (ST.Watchlist) window.Watchlist = new ST.Watchlist();
    window.Watchlist._loadInterface('st-watchlist-indicator');

    var startup = function() {
        createPageObject();
        if (ST.Attachments) window.Attachments = new ST.Attachments ();
        if (ST.Tags) window.Tags = new ST.Tags ();
        if (ST.TagQueue) window.TagQueue = new ST.TagQueue();

        window.NavBar = new ST.NavBar ();
        if (ST.Watchlist)
            jQuery('.watchlist-list-toggle').each(function() {
                var page_id = this.getAttribute('alt');
                var wl = new ST.Watchlist();
                wl.page_id = page_id;
                wl._loadInterface(this);
            });
        ST.hookCssUpload();
    }

    var bootstrappers = "#st-page-boxes-toggle-link,#st-attachments-uploadbutton,#st-attachments-managebutton,#st-tags-addlink,#st-edit-button-link,#st-edit-actions-below-fold-edit";

    var boot = function(cb) {
        jQuery(bootstrappers).unbind("click");

        var script = jQuery("<script>").attr({
            type: 'text/javascript',
            src: nlw_make_static_path("/javascript/socialtext-display-ui.js.gz")
        }).get(0);
        
        document.getElementsByTagName('head')[0].appendChild(script);

        var button = this;
        var loader = function() {
            if ( window.setup_wikiwyg ) {
                startup();
                window.setup_wikiwyg();

                if ( cb ) {
                    cb();
                    return;
                }

                if ( button.id.match(/^st-(attachments|tags|page-boxes-toggle)-/)) {
                    jQuery(button).click();
                    return;
                }

                // XXX There should be a more reliable way to do this.
                // This setTimeout fixes simple mode bug in IE and FF.
                setTimeout(function() {
                    wikiwyg.start_nlw_wikiwyg();

                    // for "Upload files" and "Add tags" buttons
                    jQuery( "#st-edit-mode-uploadbutton" ).click(function() {
                        window.Attachments._display_attach_interface();
                        return false;
                    });

                    jQuery( "#st-edit-mode-tagbutton" ).click(function() {
                        window.TagQueue._display_interface();
                        return false;
                    });
                }, 100);

                return;
            }
            setTimeout(loader, 50);
        }
        loader();

        return false;
    };

    jQuery(bootstrappers).one("click", function(){ return boot.call(this) });

    window.Tags = {
        deleteTag: function(name) {
            boot(function() {
                Tags.deleteTag(name);
            });
        }
    }

    if (Socialtext.new_page || Socialtext.start_in_edit_mode || location.hash.toLowerCase() == '#edit' ) {
        setTimeout(function() {
            jQuery("#st-edit-button-link").trigger("click");
        }, 1);
    }

    jQuery("#st-search-term").one("click", function() {
        this.value = "";
    }).one("focus", function() {
        this.value = "";
    });

    /*
    try {
        setup_wikiwyg();
    } catch(e) {
        alert(loc('setup_wikiwyg error') + ': ' + (e.description || e));
    }
    */
});

