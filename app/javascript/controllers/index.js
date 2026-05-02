import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
import BulletFormController from "controllers/bullet_form_controller"
import TimezoneCookieController from "controllers/timezone_cookie_controller"

application.register("bullet-form", BulletFormController)  // always eager
application.register("timezone-cookie", TimezoneCookieController)  // always eager
lazyLoadControllersFrom("controllers", application)    // everything else on demand
