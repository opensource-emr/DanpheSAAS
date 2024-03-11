import { Component, OnInit } from '@angular/core';
import { User } from './Model/user';
import { HttpClient } from '@angular/common/http';
import {  NgForm } from '@angular/forms';
import { Userdto } from './Model/user.dto';
import { NotifierService } from 'angular-notifier';


@Component({
  selector: 'app-security',
  templateUrl: './security.component.html',
  styleUrls: ['./security.component.css']
})
export class SecuirityComponent implements OnInit 
{
  submittedSuccessfully: boolean = false;
  private readonly notifier: NotifierService;
  user: User = new User();
  userDto:Userdto={
    hospitalName: '',
    email: '',
    contactNumber: '',
    hospitalShortName: ''
  }

  token: string|undefined;
  errorMessage: any;
  constructor(private http: HttpClient,private notifierService: NotifierService
    ) { this.token = undefined;
      this.notifier = notifierService; }

  ngOnInit() {
  }

  

  // Function to handle form submission
  Onsubmit(form: NgForm) {
    if (form.invalid) {
      alert("All fields are required");
      return;
    }
   

    console.debug(`Token [${this.token}] generated`);
    const formData = {
      hospitalName: this.user.hospitalName,
      contactNumber: this.user.contactNumber,
      email: this.user.email,
      hospitalShortName:this.user.hospitalShortName
    }
  // Created Userdto object and assign values
    let dto:Userdto=new Userdto()
      dto.hospitalName=this.user.hospitalName,
      dto.contactNumber=this.user.contactNumber,
      dto.email=this.user.email,
      dto.hospitalShortName=this.user.hospitalShortName
 // Make an HTTP POST request to the API endpoint '/api/DanpheTenant/addInfo'
 
    this.http.post('/api/DanpheTenant/addInfo', dto).subscribe((success) => this.handleSuccess(success),
      (error) => this.handleError(error)
    );  
  }
  // Function to handle HTTP error
  handleError(error: any) {
    if (error.status === 400) {
      this.errorMessage = error.error;
      if(this.errorMessage==="Email already exists"){
        this.notifier.notify('error', 'Email domain already exists .');
      }
      if(this.errorMessage==="Please Enter Corporate Email"){
        this.notifier.notify('error', 'Please Enter Only Corporate Email');
      }
  
    } else {
      this.notifier.notify('error', 'Error Occured during Submition');
    }

  }
   // Function to handle HTTP success
  handleSuccess(success: any) {
    console.log("Successed")
    this.notifier.notify('success', 'Data Submitted succesfully');
    this.notifier.notify('success', 'The URl link send to your email within some time please check your email');
    // Clear form fields after submission
    this.user.formUserGroup.reset();
    this.submittedSuccessfully = true;
    this.token=undefined;
   
    
  }
  // Function to check if a user has a specific error based on type of validator and control name
  hasError(user: User, typeofvalidator: string, controlname: string): boolean {
    return user.
      formUserGroup.
      controls[controlname].
      hasError(typeofvalidator);
  }

}

