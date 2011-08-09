{
This software is distributed under the BSD license.

Copyright (c) 2011, Tomasz Maszkowski
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
- Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
- The name of Tomasz Maszkowski may not be used to endorse or promote
  products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

History:

}
unit uModel;
interface
type

  IStudent = interface
    ['{4A2DAB03-8189-4DC6-829B-B2513AC7750E}']
    function GetName: string;
    function GetEmail: string;
    function GetDateOfBirth: TDate;
    procedure SetDateOfBirth(const Value: TDate);
    procedure SetEmail(const Value: string);
    procedure SetName(const Value: string);
    property Name: string read GetName write SetName;
    property Email: string read GetEmail write SetEmail;
    property DateOfBirth: TDate read GetDateOfBirth write SetDateOfBirth;
  end;

  ICourse = interface
    ['{7A0013F2-5EF4-4CD6-B61F-033D8414223E}']
    function GetName: string;
    function GetStudent(AIndex: Integer): IStudent;
    function GetStudentsCount: Integer;
    function HasStudent(const AStudent: IStudent): Boolean;
    function IndexOfStudent(const AStudent: IStudent): Integer;
    procedure AddStudent(const AStudent: IStudent);
    procedure RemoveStudent(const AStudent: IStudent);
    procedure SetName(const Value: string);
    property Name: string read GetName write SetName;
    property Students[AIndex: Integer]: IStudent read GetStudent;
    property StudentsCount: Integer read GetStudentsCount;
  end;

  TModel = class
    class function CreateCourse(): ICourse;
    class function CreateStudent(): IStudent;
  end;

implementation
uses
  Classes;

type
  TStudent = class(TInterfacedObject, IStudent)
  strict private
    FName: string;
    FEmail: string;
    FDateOfBirth: TDate;
  private
    { IStudent }
    function GetName: string;
    function GetEmail: string;
    function GetDateOfBirth: TDate;
    procedure SetDateOfBirth(const Value: TDate);
    procedure SetEmail(const Value: string);
    procedure SetName(const Value: string);
  end;

  TCourse = class(TInterfacedObject, ICourse)
  strict private
    FName: string;
    FStudents: IInterfaceList;
  private
    { ICourse }
    function GetName: string;
    function GetStudent(AIndex: Integer): IStudent;
    function GetStudentsCount: Integer;
    function HasStudent(const AStudent: IStudent): Boolean;
    function IndexOfStudent(const AStudent: IStudent): Integer;
    procedure AddStudent(const AStudent: IStudent);
    procedure RemoveStudent(const AStudent: IStudent);
    procedure SetName(const Value: string);
  public
    constructor Create();
  end;

{ TStudent }

function TStudent.GetDateOfBirth: TDate;
begin
  Result := FDateOfBirth;
end;

function TStudent.GetEmail: string;
begin
  Result := FEmail;
end;

function TStudent.GetName: string;
begin
  Result := FName
end;

procedure TStudent.SetDateOfBirth(const Value: TDate);
begin
  FDateOfBirth := Value
end;

procedure TStudent.SetEmail(const Value: string);
begin
  FEmail := Value;
end;

procedure TStudent.SetName(const Value: string);
begin
  FName := Value;
end;

{ TModel }
class function TModel.CreateCourse: ICourse;
begin
  Result := TCourse.Create;
end;

class function TModel.CreateStudent: IStudent;
begin
  Result := TStudent.Create;
end;

{ TCourse }

procedure TCourse.AddStudent(const AStudent: IStudent);
begin
  Assert(AStudent <> nil);
  Assert(not HasStudent(AStudent));
  FStudents.Add(AStudent);
end;

constructor TCourse.Create;
begin
  inherited Create;
  FStudents := TInterfaceList.Create;
end;

function TCourse.GetName: string;
begin
  Result := FName;
end;

function TCourse.GetStudent(AIndex: Integer): IStudent;
begin
  Result := FStudents[AIndex] as IStudent
end;

function TCourse.GetStudentsCount: Integer;
begin
  Result := FStudents.Count;
end;

function TCourse.HasStudent(const AStudent: IStudent): Boolean;
begin
  Result := IndexOfStudent(AStudent) > -1
end;

function TCourse.IndexOfStudent(const AStudent: IStudent): Integer;
begin
  Result := FStudents.IndexOf(AStudent);
end;

procedure TCourse.RemoveStudent(const AStudent: IStudent);
begin
  Assert(HasStudent(AStudent));
  FStudents.Remove(AStudent);
end;

procedure TCourse.SetName(const Value: string);
begin
  FName := Value;
end;

end.
