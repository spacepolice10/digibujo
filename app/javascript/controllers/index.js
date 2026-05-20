import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
import BulletFormController from "controllers/bullet_form_controller"
import BulletInlineEditController from "controllers/bullet_inline_edit_controller"
import TimezoneCookieController from "controllers/timezone_cookie_controller"

application.register("bullet-form", BulletFormController)  // always eager
application.register("bullet-inline-edit", BulletInlineEditController)  // always eager
application.register("timezone-cookie", TimezoneCookieController)  // always eager
lazyLoadControllersFrom("controllers", application)    // everything else on demand
