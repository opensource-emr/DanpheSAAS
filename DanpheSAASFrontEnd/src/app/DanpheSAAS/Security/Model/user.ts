import {
    FormGroup,
    FormControl,
    Validators,
    FormBuilder
  } from '@angular/forms';


export class User{
    hospitalName:string="";
    hospitalShortName:string="";
    email:string="";
    contactNumber:string="";

    formUserGroup!:FormGroup;
    constructor(){
        var _builder = new FormBuilder();
        this.formUserGroup = _builder.group({});

        this.formUserGroup.addControl("hospitalNameControl",
        new FormControl('', Validators.required)
      );
        this.formUserGroup.addControl("hospitalShortNameControl",
        new FormControl('', Validators.required)
      );
        this.formUserGroup.addControl("contactNumberControl",
        new FormControl('', [Validators.required, Validators.pattern("[0-9 ]{6,12}")])
      );
        this.formUserGroup.addControl("emailControl",
        new FormControl('', [Validators.required,Validators.email])
      );
        this.formUserGroup.addControl("recaptcha",
        new FormControl('', Validators.required)
      );
       
    }
  
}


  