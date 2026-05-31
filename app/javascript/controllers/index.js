import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading";
import { application } from "controllers/application";
import TimezoneCookieController from "controllers/timezone_cookie_controller";

application.register("timezone-cookie", TimezoneCookieController); // always eager
lazyLoadControllersFrom("controllers", application); // everything else on demand
