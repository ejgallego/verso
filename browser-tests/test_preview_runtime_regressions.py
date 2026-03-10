from playwright.sync_api import expect, Page


def record_runtime_errors(page: Page):
    errors: list[str] = []

    page.on("pageerror", lambda exc: errors.append(str(exc)))

    def on_console(msg):
        if msg.type == "error":
            errors.append(msg.text)

    page.on("console", on_console)
    return errors


def assert_no_runtime_errors(errors: list[str]):
    relevant = [
        err for err in errors
        if "cancelChildHide" in err
        or "ReferenceError" in err
        or "Uncaught" in err
    ]
    assert not relevant, "\n".join(relevant)


class TestPreviewRuntimeRegressions:
    def test_bibliography_hover_does_not_throw_and_opens_panel(self, server: str, page: Page):
        errors = record_runtime_errors(page)
        page.goto(f"{server}/The-Global-Theorem/")

        page.locator("body[data-bp-inline-preview-bound='1']").wait_for()

        trigger = page.locator(
            '.bp_inline_preview_ref[data-bp-preview-title="Bibliography: polyhedron.without.rupert"]'
        ).first
        expect(trigger).to_have_count(1)

        trigger.hover()

        panel = page.locator("#bp-inline-preview-panel")
        expect(panel).to_be_visible()
        expect(panel.locator(".bp_inline_preview_panel_body")).to_contain_text(
            "polyhedron.without.rupert"
        )

        assert_no_runtime_errors(errors)

    def test_nested_inline_subhover_uses_child_panel(self, server: str, page: Page):
        errors = record_runtime_errors(page)
        page.goto(f"{server}/Computational-Step/")

        page.locator("body[data-bp-inline-preview-bound='1']").wait_for()

        outer = page.locator(
            '.bp_inline_preview_ref[data-bp-preview-title="Theorem 7.15"]'
        ).first
        expect(outer).to_have_count(1)

        outer.hover()

        main_panel = page.locator("#bp-inline-preview-panel")
        expect(main_panel).to_be_visible()
        expect(main_panel.locator(".bp_inline_preview_panel_title")).to_have_text("Theorem 7.15")

        nested = main_panel.locator(
            '.bp_inline_preview_panel_body .bp_inline_preview_ref[data-bp-preview-title="Definition 7.10"]'
        ).first
        expect(nested).to_have_count(1)

        nested.hover()

        child_panel = page.locator("#bp-inline-preview-child-panel")
        expect(child_panel).to_be_visible()
        expect(child_panel.locator(".bp_inline_preview_panel_title")).to_have_text("Definition 7.10")
        expect(main_panel.locator(".bp_inline_preview_panel_title")).to_have_text("Theorem 7.15")

        assert_no_runtime_errors(errors)
