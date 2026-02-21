import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
import CardFormController from "controllers/card_form_controller"

application.register("card-form", CardFormController)  // always eager
lazyLoadControllersFrom("controllers", application)    // everything else on demand
