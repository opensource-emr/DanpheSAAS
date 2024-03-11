
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { HttpClientModule } from '@angular/common/http';
import { SecuirityComponent } from './security.component';
import { RECAPTCHA_SETTINGS, RecaptchaModule,RecaptchaFormsModule, RecaptchaSettings } from 'ng-recaptcha';
import { environment } from 'src/environments/environment';
import { SecurityRoutingModule } from './security-routing.module';

@NgModule({
  declarations: [
    SecuirityComponent
  ],
  imports: [
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    HttpClientModule,
    RecaptchaModule ,
    RecaptchaFormsModule,
    SecurityRoutingModule
  ],
  providers: [{provide: RECAPTCHA_SETTINGS,
    useValue: {
      siteKey: environment.recaptcha.siteKey,
    } as RecaptchaSettings,},],
  bootstrap: [SecuirityComponent]
})
export class SecuirityModule { }
