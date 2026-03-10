import re

from playwright.sync_api import expect, Page


class TestBlueprintGroupPreview:
    def test_group_chip_opens_panel_and_updates_preview(self, server: str, page: Page):
        page.goto(f"{server}/Bounding-Rotations/")

        wrapper = page.locator('.bp_wrapper[title="«lem:jensen»"]').first
        group_slot = wrapper.locator(".bp_extra_slot_group")
        chip = group_slot.locator(".bp_used_by_chip").first
        panel = group_slot.locator(".bp_used_by_panel").first

        expect(group_slot).to_have_count(1)
        expect(chip).to_have_text("group")

        chip.click()
        expect(panel).to_be_visible()
        expect(panel.locator(".bp_used_by_panel_title")).to_contain_text(
            "Group: Trigonometric inequality reductions."
        )

        items = panel.locator(".bp_used_by_item")
        expect(items).to_have_count(2)
        items.nth(1).hover()

        expect(panel.locator(".bp_used_by_preview_title")).to_have_text("Lemma 3.5")
        expect(panel.locator(".bp_used_by_preview_body")).to_contain_text("For any")

    def test_blocks_without_parent_do_not_render_group_chip(self, server: str, page: Page):
        page.goto(f"{server}/Main-Theorems/")

        wrapper = page.locator('.bp_wrapper[title="«thm:no_nopert_tight_pose»"]').first

        expect(wrapper.locator(".bp_extra_slot_group")).to_have_count(0)
