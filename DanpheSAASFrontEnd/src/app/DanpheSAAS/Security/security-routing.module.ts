import { NgModule } from '@angular/core';
import { Routes, RouterModule } from '@angular/router';
import { SecuirityComponent } from './security.component';

const routes: Routes = [  {
  path: '', component: SecuirityComponent
}
];


@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule]
})
export class SecurityRoutingModule { }
