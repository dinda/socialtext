(function ($) {

Page = {
    pageUrl: function (page_name) {
        if (!page_name) page_name = Socialtext.page_id;
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/pages/' + page_name;
    },

    cgiUrl: function () {
        return '/' + Socialtext.wiki_id + '/index.cgi';
    },

    refreshPageContent: function (force_update) {
        $.getJSON(this.pageUrl(), function (data) {
            var newRev = data.revision_id;
            var oldRev = Socialtext.revision_id;
            if ((oldRev < newRev) || force_update) {
                $.get(Page.pageUrl(), function (html) {
                    $('#st-page-content').html(html);
                    Socialtext.wikiwyg_variables.page.revision_id =
                        Socialtext.revision_id = newRev
                    $('#st-rewind-revision-count').html(newRev);
                });
            }
        });
    },

    ContentUri: function () {
        return '/'+Socialtext.wiki_id;
    },

    tagUrl: function (tag) {
        return this.pageUrl() + '/tags/' + encodeURIComponent(tag);
    },

    attachmentUrl: function (attach_id) {
        return '/data/workspaces/' + Socialtext.wiki_id +
               '/attachments/' + Socialtext.page_id + ':' + attach_id
    },

    refreshTags: function () {
        var tag_url = '?action=category_display;category=';
        $.getJSON( this.pageUrl() + '/tags', function (tags) {
            $('#st-tags-listing').html('');
            for (var i=0; i< tags.length; i++) {
                var tag = tags[i];
                $('#st-tags-listing').append(
                    $('<li>').append(
                        $('<a>')
                            .html(tag.name)
                            .attr('href', tag_url + tag.name),
                        ' ',
                        $('<a href="#">')
                            .html('[x]')
                            .attr('name', tag.name)
                            .bind('click', function () {
                                Page.delTag(this.name);
                            })
                    )
                )
            }
        });
    },

    refreshAttachments: function () {
        $.getJSON( this.pageUrl() + '/attachments', function (list) {
            $('#st-attachment-listing').html('');
            for (var i=0; i< list.length; i++) {
                var item = list[i];
                $('#st-attachment-listing').append(
                    $('<li>').append(
                        $('<a>')
                            .html(item.name)
                            .attr('href', item.uri),
                        ' ',
                        $('<a href="#">')
                            .html('[x]')
                            .attr('name', item.uri)
                            .bind('click', function () {
                                Page.delAttachment(this.name)
                            })
                    )
                )
            }
        });
    },

    delTag: function (tag) {
        $.ajax({
            type: "DELETE",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
            }
        });
    },

    delAttachment: function (url) {
        $.ajax({
            type: "DELETE",
            url: url,
            complete: function () {
                Page.refreshAttachments();
                Page.refreshPageContent();
            }
        });
    },

    addTag: function (tag) {
        $.ajax({
            type: "PUT",
            url: this.tagUrl(tag),
            complete: function () {
                Page.refreshTags();
                $('#st-tags-field').val('');
            }
        });
    }
};

var load_script = function(script_url) {
    var script = $("<script>").attr({
        type: 'text/javascript',
        src: script_url
    }).get(0);

    if ($.browser.msie)
        $(script).appendTo('head');
    else
        document.getElementsByTagName('head')[0].appendChild(script);
};

var load_ui = function(cb) {
    var script_url =
        nlw_make_s3_path("/javascript/socialtext-editor.js.gz")
        .replace(/(\d+\.\d+\.\d+\.\d+)/, '$1.' + Socialtext.make_time) ;

    load_script( script_url ); 
    var self = this;
    var loader = function() {
        // Test if it's fully loaded.
        if (Socialtext.boostrap_ui_finished != true)  {
            setTimeout(arguments.callee, 500);
            return;
        }
        cb.call(self);
    }
    setTimeout(loader, 500);
};

$(function() {
    $('#st-page-boxes-toggle-link')
        .bind('click', function() {
            $('#st-page-boxes').toggle();
            var hidden = $('#st-page-boxes').is(':hidden');
            this.innerHTML = hidden ? 'show' : 'hide';
            Cookie.set('st-page-accessories', hidden ? 'hide' : 'show');
        });

    $('#st-tags-addlink')
        .bind('click', function () {
            $(this).hide();
            $('#st-tags-field')
                .val('')
                .show()
                .focus();
        })

    $('#st-tags-field')
        .bind('blur', function () {
            $(this).hide();
            $('#st-tags-addlink').show()
        });
            

    $('#st-tags-form')
        .bind('submit', function () {
            var tag = $('#st-tags-field').val();
            Page.addTag(tag);
        });

    $('#st-attachments-uploadbutton')
        .lightbox({
            content:'#st-attachments-attachinterface',
            close:'#st-attachments-attach-closebutton'
        });

    $('#st-attachments-attach-filename')
        .val('')
        .bind('change', function () {
            var filename = $(this).val();
            if (!filename) {
                $('#st-attachments-attach-uploadmessage').html(
                    loc("Please click browse and select a file to upload.")
                );
                return false;
            }

            var filename = filename.replace(/^.*\\|\/:/, '');

            if (encodeURIComponent(filename).length > 255 ) {
                $('#st-attachments-attach-uploadmessage').html(
                    loc("Filename is too long after URL encoding.")
                );
                return false;
            }

            $('#st-attachments-attach-uploadmessage').html(
                loc('Uploading [_1]...', filename.match(/[^\\\/]+$/))
            );

            $('#st-attachments-attach-formtarget')
                .bind('load', function () {
                    $('#st-attachments-attach-uploadmessage').html(
                        loc('Upload Complete')
                    );
                    $('#st-attachments-attach-filename').attr(
                        'disabled', false
                    );
                    $('#st-attachments-attach-closebutton').attr(
                        'disabled', false
                    );
                    Page.refreshAttachments();
                    Page.refreshPageContent();
                });

            $('#st-attachments-attach-form').submit();
            $('#st-attachments-attach-closebutton').attr('disabled', true);
            $(this).attr('disabled', true);

            return false;
        });


    var editor_uri = nlw_make_s3_path('/javascript/socialtext-editor.js.gz')
        .replace(/(\d+\.\d+\.\d+\.\d+)/,'$1.'+Socialtext.make_time);

    $("#st-comment-button-link").click(function () {
        $.getScript(nlw_make_s3_path('/javascript/comment.js'),
            function () {
                var ge = new GuiEdit;
                ge.show();
            }
        );
    });

    $("#st-pagetools-email").click(function () {
        alert('not implemented');
    });

    //index.cgi?action=duplicate_popup;page_name=[% page.id %]
    $("#st-pagetools-duplicate").click(function () {
        alert('not implemented');
    });
    
    $("#st-pagetools-rename").lightbox({
        content:'#st-rename-lightbox',
        close:'#st-rename-cancellink'
    });

    $('#st-rename-form').submit(function () {
        var new_title = $('#st-rename-newname').val();
        var error = $('#st-rename-error');
        $.getJSON(
            Page.cgiUrl(),
            $(this).serialize(),
            function (data) {
                $('<input name="clobber" type="hidden">')
                    .attr('value', new_title)
                    .appendTo('#st-rename-form');
                if (data.page_exists) {
                    error.show().html(loc(
                        'The new page name you selected, "' + new_title + 
                        '", is already in use.  Please choose a different ' +
                        'name. If you are sure you wish to overwrite the ' +
                        'existing "' + new_title + '" page, please press ' +
                        '"Rename" again.'
                    ));
                }
                else if (data.page_title_bad) {
                    error.show().html(loc(
                        'The page name you selected, "' + new_title +'", ' +
                        'is not allowed.  Please enter or change the page ' +
                        'name.'
                    ));
                }
                else if (data.page_title_too_long) {
                    error.show().html(loc(
                        'The page name you selected, "' +
                        new_title + '", is too long after URL encoding'
                    ));
                }
                else if (data.same_title) {
                    error.show().html(loc(
                        'The page name you selected, "' + new_title + '", ' +
                        "is the same as the page's current title.  " +
                        'Please enter a new page name.'
                    ));
                }
                else {
                    $.hideLightbox();
                    document.location = Page.cgiUrl() + '?' + new_title;
                }
            }
        );
        return false;
    });

    $("#st-pagetools-delete").click(function () {
        if (confirm(loc("Are you sure you want to delete this page?"))) {
            var page = Socialtext.page_id;
            document.location = "index.cgi?action=delete_page;page_name=" + page;
        }
        return false;
    });

    //index.cgi?action=copy_to_workspace_popup;page_name=[% page.id %]')
    $("#st-pagetools-copy").click(function () {
        alert('not implemented');
    });

    $("#st-edit-button-link,#st-edit-actions-below-fold-edit")
        .one("click", function () {
            $('#bootstrap-loader').show();
            $.ajaxSettings.cache = true;
            $.getScript(editor_uri);
            $.ajaxSettings.cache = false;
            $('<link>')
                .attr('href', nlw_make_s3_path('/css/wikiwyg.css'))
                .attr('rel', 'stylesheet')
                .attr('media', 'wikiwyg')
                .attr('type', 'text/css')
                .appendTo('head');
        });

    $('#st-listview-submit-pdfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a PDF."));
        }
        else {
            $('#st-listview-action').val('pdf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.pdf');
            $('#st-listview-form').submit();
        }
    });

    $('#st-listview-submit-rtfexport').click(function() {
        if (!$('.st-listview-selectpage-checkbox:checked').size()) {
            alert(loc("You must check at least one page in order to create a Word document."));
        }
        else {
            $('#st-listview-action').val('rtf_export')
            $('#st-listview-filename').val(Socialtext.wiki_id + '.rtf');
            $('#st-listview-form').submit();
        }
    });

    $('#st-listview-selectall').click(function () {
        $('input[type=checkbox]').attr('checked', this.checked);
    });

    $('#st-watchlist-indicator').click(function () {
        var self = this;
        if ($(this).hasClass('on')) {
            $.get(
                location.pathname + '?action=remove_from_watchlist'+
                ';page=' + Socialtext.page_id +
                ';_=' + (new Date()).getTime(),
                function () {
                    $(self).attr('title', loc('Watch this page'));
                    $(this).removeClass('on');
                }
            );
        }
        else {
            $.get(
                location.pathname + '?action=add_to_watchlist'+
                ';page=' + Socialtext.page_id +
                ';_=' + (new Date()).getTime(),
                function () {
                    $(self).attr('title', loc('Stop watching this page'));
                    $(this).addClass('on');
                }
            );
        }
    });

    if (Socialtext.new_page ||
        Socialtext.start_in_edit_mode ||
        location.hash.toLowerCase() == '#edit' ) {
        setTimeout(function() {
            $("#st-edit-button-link").click();
        }, 500);
    }
});

})(jQuery);
