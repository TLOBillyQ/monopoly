(function () {
  var data = window.SCRAP4LUA_DATA || null;
  var noisyTerms = {
    lua: true,
    src: true,
    suites: true,
    code: true,
    test: true,
    doc: true,
  };
  var state = {
    activeQuery: "",
    selectedCollection: "all",
    selectedLevel: "all",
    exactOnly: false,
    showRawThemes: false,
    selectedScrapId: null,
  };

  function byId(id) {
    return document.getElementById(id);
  }

  function htmlEscape(text) {
    return String(text == null ? "" : text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/\"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function tokenize(text) {
    var terms = String(text || "")
      .toLowerCase()
      .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
      .replace(/[./:_-]/g, " ")
      .replace(/[^a-z0-9\s]/g, " ")
      .split(/\s+/)
      .filter(Boolean);
    var deduped = [];
    var seen = Object.create(null);
    terms.forEach(function (term) {
      if (term.length < 2 || seen[term]) {
        return;
      }
      deduped.push(term);
      seen[term] = true;
    });
    return deduped;
  }

  function collectionBadgeClass(name) {
    if (name === "test") {
      return "badge_test";
    }
    if (name === "doc") {
      return "badge_doc";
    }
    return "badge_code";
  }

  function findScrapById(scrapId) {
    var scraps = (data && data.scraps) || [];
    for (var i = 0; i < scraps.length; i += 1) {
      if (scraps[i].id === scrapId) {
        return scraps[i];
      }
    }
    return null;
  }

  function expandTerms(rawTerms) {
    var aliases = data.aliases || {};
    var themes = data.themes || [];
    var expanded = [];
    var seen = Object.create(null);

    function push(term) {
      if (!term || seen[term]) {
        return;
      }
      expanded.push(term);
      seen[term] = true;
    }

    rawTerms.forEach(function (term) {
      push(term);
      (aliases[term] || []).forEach(push);
      themes.forEach(function (theme) {
        if (theme.center === term) {
          (theme.related_terms || []).forEach(push);
        }
      });
    });

    return expanded;
  }

  function runSearch(queryText) {
    var rawTerms = tokenize(queryText);
    var expandedTerms = expandTerms(rawTerms);
    var matches = [];

    (data.scraps || []).forEach(function (scrap) {
      if (state.selectedCollection !== "all" && scrap.collection !== state.selectedCollection) {
        return;
      }
      if (state.selectedLevel !== "all" && scrap.level !== state.selectedLevel) {
        return;
      }

      var score = 0;
      var reasons = [];
      rawTerms.forEach(function (term) {
        if ((scrap.terms || []).indexOf(term) >= 0) {
          score += 8;
          reasons.push("direct:" + term);
        }
      });

      if (!state.exactOnly) {
        expandedTerms.forEach(function (term) {
          if (rawTerms.indexOf(term) === -1 && (scrap.terms || []).indexOf(term) >= 0) {
            score += 3;
            reasons.push("expanded:" + term);
          }
        });
      }

      if (score > 0) {
        matches.push({
          scrap_id: scrap.id,
          path: scrap.path,
          title: scrap.title,
          level: scrap.level,
          collection: scrap.collection,
          score: score,
          reasons: reasons,
        });
      }
    });

    matches.sort(function (left, right) {
      if (right.score !== left.score) {
        return right.score - left.score;
      }
      if (left.path !== right.path) {
        return left.path.localeCompare(right.path);
      }
      return String(left.title).localeCompare(String(right.title));
    });

    return {
      rawTerms: rawTerms,
      expandedTerms: expandedTerms,
      matches: matches.slice(0, 50),
    };
  }

  function filteredThemes() {
    return (data.themes || []).filter(function (theme) {
      if (state.showRawThemes) {
        return true;
      }
      if (noisyTerms[theme.center]) {
        return false;
      }
      if ((theme.scrap_count || 0) > (((data.metadata && data.metadata.scrap_count) || 1) * 0.3)) {
        return false;
      }
      return true;
    }).slice(0, 8);
  }

  function renderFilters() {
    var collections = { all: true };
    var levels = { all: true };
    (data.scraps || []).forEach(function (scrap) {
      collections[scrap.collection] = true;
      levels[scrap.level] = true;
    });

    var collectionSelect = byId("collection_filter");
    var levelSelect = byId("level_filter");

    Object.keys(collections).sort().forEach(function (name) {
      if (name === "all") {
        return;
      }
      collectionSelect.insertAdjacentHTML("beforeend", '<option value="' + htmlEscape(name) + '">' + htmlEscape(name) + '</option>');
    });
    Object.keys(levels).sort().forEach(function (name) {
      if (name === "all") {
        return;
      }
      levelSelect.insertAdjacentHTML("beforeend", '<option value="' + htmlEscape(name) + '">' + htmlEscape(name) + '</option>');
    });
  }

  function renderThemes() {
    var list = byId("theme_list");
    var themes = filteredThemes();
    byId("theme_notice").textContent = state.showRawThemes ? "Raw clustering" : "Curated spotlight";
    list.innerHTML = "";

    themes.forEach(function (theme) {
      var themeQuery = [theme.center].concat(theme.related_terms || []).join(" ");
      var html = [
        '<button class="theme_card" data-theme-query="', htmlEscape(themeQuery), '">',
        '<div class="theme_title"><strong>', htmlEscape(theme.center), '</strong><span class="result_score">', htmlEscape(String(theme.strength || 0)), '</span></div>',
        '<div class="theme_meta">', htmlEscape(String(theme.scrap_count || 0)), ' scraps linked</div>',
        '<div class="theme_terms">',
        (theme.related_terms || []).slice(0, 4).map(function (term) {
          return '<span class="chip">' + htmlEscape(term) + '</span>';
        }).join(""),
        '</div></button>'
      ].join("");
      list.insertAdjacentHTML("beforeend", html);
    });

    Array.prototype.forEach.call(list.querySelectorAll("[data-theme-query]"), function (button) {
      button.addEventListener("click", function () {
        var queryText = button.getAttribute("data-theme-query") || "";
        byId("query_input").value = queryText;
        state.activeQuery = queryText;
        state.selectedScrapId = null;
        render();
      });
    });
  }

  function renderSuggestedQueries() {
    var chips = [
      "choice owner_role_id",
      "bankruptcy feedback",
      "market paid purchase",
      "src.game.systems",
    ];
    var container = byId("query_chip_list");
    container.innerHTML = chips.map(function (chip) {
      return '<button class="query_chip" data-query="' + htmlEscape(chip) + '">' + htmlEscape(chip) + '</button>';
    }).join("");

    Array.prototype.forEach.call(container.querySelectorAll("[data-query]"), function (button) {
      button.addEventListener("click", function () {
        var queryText = button.getAttribute("data-query") || "";
        byId("query_input").value = queryText;
        state.activeQuery = queryText;
        state.selectedScrapId = null;
        render();
      });
    });
  }

  function bindInspectorLinks(root) {
    Array.prototype.forEach.call(root.querySelectorAll("[data-scrap-id]"), function (button) {
      button.addEventListener("click", function () {
        state.selectedScrapId = Number(button.getAttribute("data-scrap-id"));
        render();
      });
    });
  }

  function renderInspector(match) {
    var title = byId("inspector_title");
    var subtitle = byId("inspector_subtitle");
    var path = byId("inspector_path");
    var meta = byId("inspector_meta");
    var reasons = byId("inspector_reasons");
    var terms = byId("inspector_terms");
    var requires = byId("inspector_requires");
    var neighbors = byId("inspector_neighbors");
    var related = byId("inspector_related");

    if (!match) {
      title.textContent = "Nothing selected";
      subtitle.textContent = "Select a match card to inspect its terms, related scraps, and nearby symbols.";
      path.textContent = "-";
      meta.innerHTML = "";
      reasons.innerHTML = "";
      terms.innerHTML = "";
      requires.innerHTML = "";
      neighbors.innerHTML = "";
      related.innerHTML = "";
      return;
    }

    var scrap = findScrapById(match.scrap_id);
    var samePath = (data.scraps || []).filter(function (item) {
      return item.path === scrap.path && item.id !== scrap.id;
    }).slice(0, 6);
    var relatedScraps = (data.scraps || []).filter(function (item) {
      if (item.id === scrap.id) {
        return false;
      }
      var overlap = (item.terms || []).filter(function (term) {
        return (scrap.terms || []).indexOf(term) >= 0;
      });
      return overlap.length >= 2;
    }).slice(0, 6);

    title.textContent = scrap.title;
    subtitle.textContent = scrap.collection + " / " + scrap.level;
    path.textContent = scrap.path;
    meta.innerHTML = [
      '<dt>Collection</dt><dd>' + htmlEscape(scrap.collection) + '</dd>',
      '<dt>Level</dt><dd>' + htmlEscape(scrap.level) + '</dd>',
      '<dt>Kind</dt><dd>' + htmlEscape(scrap.kind || '-') + '</dd>',
      '<dt>ID</dt><dd>' + htmlEscape(String(scrap.id)) + '</dd>'
    ].join("");
    reasons.innerHTML = (match.reasons || []).map(function (item) {
      return '<span class="reason_chip">' + htmlEscape(item) + '</span>';
    }).join("");
    terms.innerHTML = (scrap.terms || []).slice(0, 24).map(function (item) {
      return '<span class="term_chip">' + htmlEscape(item) + '</span>';
    }).join("");
    requires.innerHTML = (scrap.requires || []).length > 0 ? (scrap.requires || []).map(function (item) {
      return '<span class="term_chip">' + htmlEscape(item) + '</span>';
    }).join("") : '<span class="minor_note">No explicit require list</span>';
    neighbors.innerHTML = samePath.length > 0 ? samePath.map(function (item) {
      return '<button class="link_item" data-scrap-id="' + htmlEscape(String(item.id)) + '"><strong>' + htmlEscape(item.title) + '</strong><span class="link_meta">' + htmlEscape(item.level) + '</span></button>';
    }).join("") : '<span class="minor_note">No sibling scraps on the same path.</span>';
    related.innerHTML = relatedScraps.length > 0 ? relatedScraps.map(function (item) {
      return '<button class="link_item" data-scrap-id="' + htmlEscape(String(item.id)) + '"><strong>' + htmlEscape(item.title) + '</strong><span class="link_meta">' + htmlEscape(item.path) + '</span></button>';
    }).join("") : '<span class="minor_note">No related scraps above the overlap threshold.</span>';

    bindInspectorLinks(neighbors);
    bindInspectorLinks(related);
  }

  function renderResults() {
    var queryText = state.activeQuery.trim();
    var list = byId("results_list");
    var empty = byId("empty_state");
    var title = byId("results_title");
    var count = byId("results_count_label");
    var expandedTermsLabel = byId("expanded_terms_label");

    if (!queryText) {
      list.innerHTML = "";
      empty.classList.remove("hidden");
      title.textContent = "Recommended entry points";
      count.textContent = "0 results";
      expandedTermsLabel.textContent = "";
      renderInspector(null);
      return;
    }

    var result = runSearch(queryText);
    title.textContent = "Search results";
    count.textContent = String(result.matches.length) + " results";
    expandedTermsLabel.textContent = result.expandedTerms.length > 0 ? "expanded: " + result.expandedTerms.join(", ") : "";
    list.innerHTML = result.matches.map(function (match) {
      var selectedClass = state.selectedScrapId === match.scrap_id ? " is_selected" : "";
      return [
        '<button class="result_card', selectedClass, '" data-result-id="', htmlEscape(String(match.scrap_id)), '">',
        '<div class="result_title"><strong>', htmlEscape(match.title), '</strong><span class="result_score">', htmlEscape(String(match.score)), '</span></div>',
        '<div class="result_path">', htmlEscape(match.path), '</div>',
        '<div class="result_meta"><span class="collection_badge ', collectionBadgeClass(match.collection), '">', htmlEscape(match.collection), '</span> · ', htmlEscape(match.level), '</div>',
        '<div class="result_chips">',
        (match.reasons || []).slice(0, 5).map(function (reason) {
          return '<span class="chip">' + htmlEscape(reason) + '</span>';
        }).join(""),
        '</div>',
        '</button>'
      ].join("");
    }).join("");

    empty.classList.toggle("hidden", result.matches.length > 0);

    if (!state.selectedScrapId && result.matches[0]) {
      state.selectedScrapId = result.matches[0].scrap_id;
    }

    var activeMatch = null;
    result.matches.forEach(function (match) {
      if (match.scrap_id === state.selectedScrapId) {
        activeMatch = match;
      }
    });
    if (!activeMatch) {
      activeMatch = result.matches[0] || null;
      state.selectedScrapId = activeMatch ? activeMatch.scrap_id : null;
    }
    renderInspector(activeMatch);

    Array.prototype.forEach.call(list.querySelectorAll("[data-result-id]"), function (button) {
      button.addEventListener("click", function () {
        state.selectedScrapId = Number(button.getAttribute("data-result-id"));
        render();
      });
    });
  }

  function renderCounts() {
    byId("scrap_count_label").textContent = String((data.scraps || []).length);
    byId("term_count_label").textContent = String((data.terms || []).length);
    byId("theme_count_label").textContent = String((data.themes || []).length);
    byId("brand_subtitle").textContent = ((data.metadata && data.metadata.project_name) || "Project") + " archive: search scraps, inspect reasons, and follow semantic trails.";
  }

  function render() {
    renderThemes();
    renderResults();
  }

  function bindControls() {
    byId("query_input").addEventListener("input", function (event) {
      state.activeQuery = event.target.value || "";
      state.selectedScrapId = null;
      render();
    });
    byId("collection_filter").addEventListener("change", function (event) {
      state.selectedCollection = event.target.value || "all";
      state.selectedScrapId = null;
      render();
    });
    byId("level_filter").addEventListener("change", function (event) {
      state.selectedLevel = event.target.value || "all";
      state.selectedScrapId = null;
      render();
    });
    byId("exact_toggle").addEventListener("change", function (event) {
      state.exactOnly = event.target.checked === true;
      state.selectedScrapId = null;
      render();
    });
    byId("raw_theme_toggle").addEventListener("change", function (event) {
      state.showRawThemes = event.target.checked === true;
      render();
    });
  }

  function boot() {
    if (!data) {
      document.body.innerHTML = '<main class="app_shell"><section class="panel"><h1>Missing SCRAP4LUA_DATA</h1><p>Generate the viewer bundle before opening this page.</p></section></main>';
      return;
    }
    renderCounts();
    renderFilters();
    renderSuggestedQueries();
    bindControls();
    render();
  }

  boot();
}());
