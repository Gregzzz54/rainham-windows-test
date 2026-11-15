"use strict";

const menu = document.querySelector(".menu-toggle");
const navigation = document.querySelector("#navigation");

function closeMenu() {
  menu.setAttribute("aria-expanded", "false");
  navigation.classList.remove("is-open");
}

menu.addEventListener("click", () => {
  const expanded = menu.getAttribute("aria-expanded") !== "true";
  menu.setAttribute("aria-expanded", String(expanded));
  navigation.classList.toggle("is-open", expanded);
});

navigation.addEventListener("click", event => {
  if (event.target.closest("a")) closeMenu();
});

document.addEventListener("keydown", event => {
  if (event.key === "Escape" && menu.getAttribute("aria-expanded") === "true") {
    closeMenu();
    menu.focus();
  }
});

document.querySelector("#quote-form").addEventListener("submit", event => {
  event.preventDefault();
  const form = event.currentTarget;
  if (!form.reportValidity()) return;
  const data = new FormData(form);
  const message = [
    "Quotation enquiry for Rainham Windows",
    `Name: ${data.get("name")}`,
    `Email: ${data.get("email")}`,
    `Property postcode: ${data.get("postcode")}`,
    `Project: ${data.get("product")}`,
    "",
    String(data.get("details")).trim()
  ].join("\n");

  document.querySelector("#enquiry-message").value = message;
  document.querySelector("#enquiry-status").textContent =
    "Your message is prepared, not sent. Verified contact details are still required before you can send it to the business.";
  document.querySelector("#enquiry-result").hidden = false;
  document.querySelector("#enquiry-message").focus();
});

document.querySelector("#select-message").addEventListener("click", () => {
  document.querySelector("#enquiry-message").select();
  document.querySelector("#enquiry-status").textContent =
    "Message selected. Use your device's Copy command. The enquiry has not been sent.";
});
