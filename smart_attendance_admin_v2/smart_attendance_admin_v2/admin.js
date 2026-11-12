const API_BASE = 'https://attendance-cloudflare.quangcuongdk1.workers.dev';
let students = [], classes = [], attendance = [], accounts = [], studentAccounts = [], session = null, editingStudentId = null, editingClassId = null, faceStream = null, faceImageBase64 = null;
const $ = id => document.getElementById(id);

function showToast(message){const toast=$('toast');toast.textContent=message;toast.classList.add('show');setTimeout(()=>toast.classList.remove('show'),2500);}
function escapeHtml(value){return String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]));}
// Các mốc SQLite CURRENT_TIMESTAMP dạng "YYYY-MM-DD HH:mm:ss" đều là UTC.
// Các mốc ISO có Z hoặc offset cũng là thời điểm tuyệt đối.
// Chỉ chuyển khi HIỂN THỊ, không ghi lại vào database.
function formatDate(value) {
  if (!value) return '-';
  const raw = String(value).trim();
  const sqliteUtc = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?$/;
  const normalized = sqliteUtc.test(raw) ? raw.replace(' ', 'T') + 'Z' : raw;
  const date = new Date(normalized);
  if (Number.isNaN(date.getTime())) return raw;
  return new Intl.DateTimeFormat('vi-VN', {
    timeZone: 'Asia/Ho_Chi_Minh',
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23'
  }).format(date);
}
function normalizeStatus(status){const s=String(status??'').toLowerCase();if(s.includes('muộn')||s.includes('muon')||s.includes('late'))return'late';if(s.includes('vắng')||s.includes('vang')||s.includes('absent'))return'absent';return'present';}
function statusLabel(status){const type=normalizeStatus(status);return type==='late'?'Muộn':type==='absent'?'Vắng':'Có mặt';}
async function api(path,options={}){
 const requestSession=session;
 const headers={...(options.headers||{})};if(session?.token)headers.Authorization='Bearer '+session.token;
 const response=await fetch(API_BASE+path,{...options,headers});let data={};try{data=await response.json()}catch{}
 if(requestSession!==session)throw new Error('Phiên đăng nhập đã thay đổi.');
 if(!response.ok||data.success===false)throw new Error(data.message||`HTTP ${response.status}`);
 return data;
}
async function checkApi(){try{const data=await api('/api/health');$('apiDot').style.background='#16a34a';$('apiStatus').textContent=data.success?'API đang hoạt động':'API lỗi';}catch(e){$('apiDot').style.background='#dc3545';$('apiStatus').textContent='Không kết nối API';}}
async function loadData(){
 if(!session)return;
 try{
  const role=session.user.role;
  if(role==='admin'){
   const [studentData,classData,attendanceData]=await Promise.all([api('/api/students'),api('/api/classes'),api('/api/role/attendance')]);
   students=studentData.data||[];classes=classData.data||[];attendance=attendanceData.data||[];
   await Promise.all([loadAccounts(),loadRequests(),loadStudentAccounts()]);
  }else{
   students=[];classes=[];
   const d=await api('/api/role/attendance');attendance=d.data||[];
  }
  renderAll();$('lastUpdated').textContent='Cập nhật '+new Date().toLocaleTimeString('vi-VN');
 }catch(e){showToast('Không tải được dữ liệu: '+e.message);}
}
function renderAll(){renderDashboard();renderStudents();renderClasses();renderAttendance();}
function renderDashboard(){const present=attendance.filter(x=>normalizeStatus(x.status)==='present').length,late=attendance.filter(x=>normalizeStatus(x.status)==='late').length,absent=attendance.filter(x=>normalizeStatus(x.status)==='absent').length,total=attendance.length,presentRate=total?Math.round(present/total*100):0;$('statStudents').textContent=students.length;$('statClasses').textContent=classes.length;$('statAttendance').textContent=total;$('statPresent').textContent=presentRate+'%';$('legendPresent').textContent=present;$('legendLate').textContent=late;$('legendAbsent').textContent=absent;const p1=total?present/total*100:0,p2=p1+(total?late/total*100:0);$('donut').style.background=`conic-gradient(#16a34a 0 ${p1}%, #ea8b16 ${p1}% ${p2}%, #dc3545 ${p2}% 100%)`;const recent=[...attendance].sort((a,b)=>new Date(b.attendance_time)-new Date(a.attendance_time)).slice(0,6);$('recentAttendance').innerHTML=recent.length?recent.map(x=>`<div class="recent-item"><div><b>${escapeHtml(x.full_name||x.student_code||'Sinh viên')}</b><small>${escapeHtml(x.student_code||'')} · ${escapeHtml(x.class_name||x.class_code||'')}<br>${formatDate(x.attendance_time)}</small></div><span class="status ${normalizeStatus(x.status)}">${statusLabel(x.status)}</span></div>`).join(''):'<div class="empty">Chưa có lượt điểm danh.</div>';$('apiUrlText').textContent=API_BASE;}
function hasFace(x){return Boolean(x.has_face||x.face_registered||x.face_data_id||x.embedding||x.face_embedding||x.face_count>0);}
function renderStudents(){const keyword=($('studentSearch').value||'').toLowerCase().trim(),filtered=students.filter(x=>String(x.student_code||'').toLowerCase().includes(keyword)||String(x.full_name||'').toLowerCase().includes(keyword));$('studentCount').textContent=`${filtered.length} sinh viên`;$('studentsTable').innerHTML=filtered.length?filtered.map(x=>`<tr><td>${escapeHtml(x.id)}</td><td><b>${escapeHtml(x.student_code)}</b></td><td>${escapeHtml(x.full_name)}</td><td><span class="face-status ${hasFace(x)?'ok':'no'}">${hasFace(x)?'✓ Đã đăng ký':'Chưa có'}</span></td><td>${formatDate(x.created_at)}</td><td><div class="row-actions"><button class="small-btn" onclick="editStudent(${Number(x.id)})">Sửa</button><button class="small-btn danger" onclick="deleteStudent(${Number(x.id)})">Xóa</button></div></td></tr>`).join(''):'<tr><td colspan="6" class="empty">Không có sinh viên.</td></tr>';}
function renderClasses(){$('classesTable').innerHTML=classes.length?classes.map(x=>`<tr><td>${escapeHtml(x.id)}</td><td><b>${escapeHtml(x.class_code)}</b></td><td>${escapeHtml(x.class_name)}</td><td>${Number(x.latitude).toFixed(6)}</td><td>${Number(x.longitude).toFixed(6)}</td><td>${Number(x.radius).toFixed(0)} m</td><td><div class="row-actions"><button class="small-btn" onclick="editClass(${Number(x.id)})">Sửa</button><button class="small-btn danger" onclick="deleteClass(${Number(x.id)})">Xóa</button></div></td></tr>`).join(''):'<tr><td colspan="7" class="empty">Chưa có lớp học.</td></tr>';}
function renderAttendance(){const keyword=($('attendanceSearch').value||'').toLowerCase().trim(),filtered=[...attendance].sort((a,b)=>new Date(b.attendance_time)-new Date(a.attendance_time)).filter(x=>`${x.full_name||''} ${x.student_code||''} ${x.class_name||''} ${x.class_code||''}`.toLowerCase().includes(keyword));$('attendanceCount').textContent=`${filtered.length} lượt`;$('attendanceTable').innerHTML=filtered.length?filtered.map(x=>{const type=normalizeStatus(x.status);return`<tr><td>${formatDate(x.attendance_time)}</td><td><b>${escapeHtml(x.full_name||'-')}</b><br><span class="gps">${escapeHtml(x.student_code||'')}</span></td><td>${escapeHtml(x.class_name||x.class_code||'-')}</td><td><span class="status ${type}">${statusLabel(x.status)}</span></td><td>${x.distance!=null?Number(x.distance).toFixed(1)+' m':'-'}</td><td>${x.face_similarity!=null?(Number(x.face_similarity)*100).toFixed(1)+'%':'-'}</td><td class="gps">${x.latitude!=null?Number(x.latitude).toFixed(5):'-'}<br>${x.longitude!=null?Number(x.longitude).toFixed(5):'-'}</td></tr>`}).join(''):'<tr><td colspan="7" class="empty">Không có lịch sử điểm danh.</td></tr>';}

function resetStudentForm(){editingStudentId=null;$('studentFormTitle').textContent='Thêm sinh viên';$('studentCode').value='';$('studentName').value='';$('studentCode').disabled=false;$('studentMessage').textContent='';faceImageBase64=null;$('facePreview').innerHTML='<span>📷</span><small>Chưa chụp khuôn mặt</small>';}
function openStudentForm(student=null){resetStudentForm();if(student){editingStudentId=student.id;$('studentFormTitle').textContent='Sửa sinh viên';$('studentCode').value=student.student_code||'';$('studentName').value=student.full_name||'';$('studentCode').disabled=true;}$('addStudentForm').hidden=false;$('studentMessage').textContent='';}
async function saveStudent(){const code=$('studentCode').value.trim(),name=$('studentName').value.trim(),msg=$('studentMessage');if(!code||!name){msg.textContent='Vui lòng nhập đủ mã sinh viên và họ tên.';msg.style.color='#dc3545';return;}try{let data;if(editingStudentId){data=await api(`/api/students/${editingStudentId}`,{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({student_code:code,full_name:name})});}else{data=await api('/api/students',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({student_code:code,full_name:name})});}if(data.success===false)throw new Error(data.message||'Không thể lưu sinh viên.');const id=data.id||(data.student&&data.student.id)||editingStudentId;if(faceImageBase64&&id){showToast('Ảnh camera chỉ là bản xem trước; cần Flutter MobileFaceNet để đăng ký embedding.');}await stopFaceCamera();$('addStudentForm').hidden=true;await loadData();showToast(editingStudentId?'Đã sửa sinh viên.':'Đã thêm sinh viên.');}catch(e){msg.textContent=e.message;msg.style.color='#dc3545';}}
async function editStudent(id){const student=students.find(x=>Number(x.id)===Number(id));if(student)openStudentForm(student);}
async function deleteStudent(id){const student=students.find(x=>Number(x.id)===Number(id));if(!student||!confirm(`Xóa sinh viên "${student.full_name}" (${student.student_code})?\\nDữ liệu khuôn mặt của sinh viên cũng sẽ được xóa nếu API hỗ trợ.`))return;try{await api(`/api/students/${id}`,{method:'DELETE'});await loadData();showToast('Đã xóa sinh viên.');}catch(e){showToast('Xóa thất bại: '+e.message);}}

async function startFaceCamera(){try{if(!navigator.mediaDevices?.getUserMedia)throw new Error('Trình duyệt không hỗ trợ camera.');faceStream=await navigator.mediaDevices.getUserMedia({video:{facingMode:'user',width:{ideal:640},height:{ideal:480}},audio:false});const video=$('faceVideo');video.srcObject=faceStream;video.hidden=false;$('facePreview').hidden=true;$('startFaceBtn').disabled=true;$('captureFaceBtn').disabled=false;$('stopFaceBtn').disabled=false;$('faceMessage').textContent='Đưa khuôn mặt vào giữa khung rồi bấm Chụp khuôn mặt.';}catch(e){$('faceMessage').textContent='Không mở được camera: '+e.message;$('faceMessage').style.color='#dc3545';}}
function captureFace(){const video=$('faceVideo'),canvas=$('faceCanvas');if(!video.videoWidth)return;$('faceCanvas').width=video.videoWidth;$('faceCanvas').height=video.videoHeight;canvas.getContext('2d').drawImage(video,0,0,canvas.width,canvas.height);faceImageBase64=canvas.toDataURL('image/jpeg',0.85);$('facePreview').hidden=false;$('facePreview').innerHTML=`<img src="${faceImageBase64}" alt="Khuôn mặt"><small>✓ Đã chụp khuôn mặt</small>`;$('faceMessage').textContent='Đã chụp ảnh xem trước. Ảnh không được gửi làm dữ liệu khuôn mặt; hãy dùng Flutter để tạo embedding MobileFaceNet.';$('faceMessage').style.color='#16833e';}
async function stopFaceCamera(){if(faceStream){faceStream.getTracks().forEach(t=>t.stop());faceStream=null;}const video=$('faceVideo');video.srcObject=null;video.hidden=true;$('facePreview').hidden=false;$('startFaceBtn').disabled=false;$('captureFaceBtn').disabled=true;$('stopFaceBtn').disabled=true;}

function resetClassForm(){editingClassId=null;$('classFormTitle').textContent='Thêm lớp học';$('classCode').value='';$('className').value='';$('classLatitude').value='';$('classLongitude').value='';$('classRadius').value='100';$('classCode').disabled=false;$('classMessage').textContent='';}
function openClassForm(item=null){resetClassForm();if(item){editingClassId=item.id;$('classFormTitle').textContent='Sửa lớp học';$('classCode').value=item.class_code||'';$('className').value=item.class_name||'';$('classLatitude').value=item.latitude??'';$('classLongitude').value=item.longitude??'';$('classRadius').value=item.radius??100;$('classCode').disabled=true;}$('classForm').hidden=false;}
async function saveClass(){const code=$('classCode').value.trim(),name=$('className').value.trim(),latitude=Number($('classLatitude').value),longitude=Number($('classLongitude').value),radius=Number($('classRadius').value),msg=$('classMessage');if(!$('classLatitude').value.trim()||!$('classLongitude').value.trim()||Math.abs(latitude)>90||Math.abs(longitude)>180||!code||!name||!Number.isFinite(latitude)||!Number.isFinite(longitude)||!Number.isFinite(radius)||radius<=0){msg.textContent='Vui lòng nhập đầy đủ và đúng tọa độ/bán kính.';msg.style.color='#dc3545';return;}try{const body={class_code:code,class_name:name,latitude,longitude,radius};const data=await api(editingClassId?`/api/classes/${editingClassId}`:'/api/classes',{method:editingClassId?'PUT':'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});if(data.success===false)throw new Error(data.message||'Không thể lưu lớp.');$('classForm').hidden=true;await loadData();showToast(editingClassId?'Đã sửa lớp.':'Đã thêm lớp.');}catch(e){msg.textContent=e.message;msg.style.color='#dc3545';}}
async function editClass(id){const item=classes.find(x=>Number(x.id)===Number(id));if(item)openClassForm(item);}
async function deleteClass(id){const item=classes.find(x=>Number(x.id)===Number(id));if(!item||!confirm(`Xóa lớp "${item.class_name}" (${item.class_code})?`))return;try{await api(`/api/classes/${id}`,{method:'DELETE'});await loadData();showToast('Đã xóa lớp.');}catch(e){showToast('Xóa lớp thất bại: '+e.message);}}
function getClassLocation(){if(!navigator.geolocation){$('classMessage').textContent='Trình duyệt không hỗ trợ GPS.';return;}$('classMessage').textContent='Đang lấy vị trí...';navigator.geolocation.getCurrentPosition(p=>{$('classLatitude').value=p.coords.latitude.toFixed(6);$('classLongitude').value=p.coords.longitude.toFixed(6);$('classMessage').textContent=`Đã lấy vị trí. Độ chính xác khoảng ${p.coords.accuracy.toFixed(1)} m.`;$('classMessage').style.color='#16833e';},e=>{$('classMessage').textContent='Không lấy được vị trí: '+e.message;$('classMessage').style.color='#dc3545';},{enableHighAccuracy:true,timeout:15000,maximumAge:0});}

function setupNavigation(){document.querySelectorAll('.nav-item').forEach(btn=>btn.addEventListener('click',()=>{document.querySelectorAll('.nav-item').forEach(x=>x.classList.remove('active'));document.querySelectorAll('.page').forEach(x=>x.classList.remove('active'));btn.classList.add('active');$('page-'+btn.dataset.page).classList.add('active');$('pageTitle').textContent=btn.querySelector('span').textContent;$('sidebar').classList.remove('open');}));}
const roleNames={admin:'Quản trị viên',teacher:'Giáo viên',parent:'Phụ huynh'};
function setAuthMessage(id,text,ok=false){$(id).textContent=text;$(id).style.color=ok?'#15803d':'#b91c1c';}
function switchToPage(page){const btn=document.querySelector(`.nav-item[data-page="${page}"]`);if(btn)btn.click();}
function enterSession(data){
 clearSessionView();
 session=data;
 $('authGate').hidden=true;$('appShell').hidden=false;
 $('currentUser').textContent=`${data.user.username} · ${roleNames[data.user.role]||data.user.role}`;
 const isAdmin=data.user.role==='admin';
 document.querySelectorAll('.admin-only').forEach(el=>el.hidden=!isAdmin);
 document.querySelectorAll('.nav-item[data-page="students"],.nav-item[data-page="classes"],.nav-item[data-page="dashboard"]').forEach(el=>el.hidden=!isAdmin);
 switchToPage(isAdmin?'dashboard':'attendance');
}
function clearSessionView(){
 attendance=[];students=[];classes=[];accounts=[];studentAccounts=[];
 for(const id of ['attendanceTable','studentsTable','classesTable','accountsTable','requestsTable','studentAccountsTable','v4RosterList','v4ScheduleTable']){if($(id))$(id).replaceChildren();}
 if($('attendanceCount'))$('attendanceCount').textContent='0 lượt';
 if($('lastUpdated'))$('lastUpdated').textContent='--';
 renderDashboard();
 v4Token=null;v4RosterIds.clear();v4Members.clear();v4Schedules=[];v4Editing=null;
}
function logout(){clearSessionView();session=null;attendance=[];students=[];classes=[];accounts=[];studentAccounts=[];hideStudentCredentials();$('appShell').hidden=true;$('authGate').hidden=false;$('loginPassword').value='';}
async function loadAccounts(){
 try{const d=await api('/api/admin/accounts');accounts=d.data||[];
 $('accountsTable').innerHTML=accounts.length?accounts.map(a=>`<tr><td>${escapeHtml(a.id)}</td><td>${escapeHtml(a.username)}</td><td>${escapeHtml(a.email)}</td><td>${escapeHtml(roleNames[a.role]||a.role)}</td><td>${escapeHtml(a.status)}</td><td>${formatDate(a.created_at)}</td></tr>`).join(''):'<tr><td colspan="6" class="empty">Chưa có tài khoản.</td></tr>';
 $('accountsMessage').textContent='';renderAssignmentOptions();
 }catch(e){$('accountsMessage').textContent=e.message;}
}
async function loadRequests(){
 try{const d=await api('/api/admin/registration-requests');const rows=d.data||[];
 $('requestsTable').innerHTML=rows.length?rows.map(r=>`<tr><td>${escapeHtml(r.username)}</td><td>${escapeHtml(r.email)}</td><td>${escapeHtml(roleNames[r.requested_role]||r.requested_role)}</td><td>${formatDate(r.created_at)}</td><td><button class="small-btn" data-review="approve" data-id="${Number(r.request_id)}">Duyệt</button> <button class="small-btn danger" data-review="reject" data-id="${Number(r.request_id)}">Từ chối</button></td></tr>`).join(''):'<tr><td colspan="5" class="empty">Không có yêu cầu chờ duyệt.</td></tr>';
 $('requestsMessage').textContent='';
 }catch(e){$('requestsMessage').textContent=e.message;}
}
async function reviewRegistration(id,action){
 if(!confirm(action==='approve'?'Duyệt tài khoản này?':'Từ chối tài khoản này?'))return;
 try{await api(`/api/admin/registration-requests/${id}/${action}`,{method:'POST'});showToast(action==='approve'?'Đã duyệt tài khoản.':'Đã từ chối đăng ký.');await Promise.all([loadRequests(),loadAccounts()]);}
 catch(e){$('requestsMessage').textContent=e.message;}
}
function renderAssignmentOptions(){
 const options=(arr,label)=>'<option value="">-- Chọn '+label+' --</option>'+arr.map(a=>`<option value="${Number(a.id)}">${escapeHtml(a.username)} (${escapeHtml(a.email)})</option>`).join('');
 $('teacherSelect').innerHTML=options(accounts.filter(x=>x.role==='teacher'&&x.status==='active'),'giáo viên');
 $('parentSelect').innerHTML=options(accounts.filter(x=>x.role==='parent'&&x.status==='active'),'phụ huynh');
 $('assignedClassSelect').innerHTML='<option value="">-- Chọn lớp --</option>'+classes.map(c=>`<option value="${Number(c.id)}">${escapeHtml(c.class_code)} · ${escapeHtml(c.class_name)}</option>`).join('');
 $('assignedStudentSelect').innerHTML='<option value="">-- Chọn học sinh --</option>'+students.map(s=>`<option value="${Number(s.id)}">${escapeHtml(s.student_code)} · ${escapeHtml(s.full_name)}</option>`).join('');
}
async function doAssignment(type){
 const teacher=type==='teacher';const a=$(teacher?'teacherSelect':'parentSelect').value;const b=$(teacher?'assignedClassSelect':'assignedStudentSelect').value;
 const el=$(teacher?'teacherAssignMsg':'parentAssignMsg');if(!a||!b){el.textContent='Hãy chọn đủ hai mục.';return;}
 try{const url=teacher?'/api/admin/teacher-classes':'/api/admin/parent-students';const payload=teacher?{account_id:Number(a),class_id:Number(b)}:{account_id:Number(a),student_id:Number(b)};
 const d=await api(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});el.textContent=d.message||'Đã cập nhật thành công.';}
 catch(e){el.textContent=e.message;}
}

// Học sinh: tài khoản được quản lý tách biệt với accounts (Admin/Teacher/Parent).
const selectedStudentAccountIds = new Set();
let deletingStudentAccounts = false;
function updateStudentSelection(){
 const valid = new Set(studentAccounts.map(a=>Number(a.account_id)));
 for(const id of selectedStudentAccountIds) if(!valid.has(id)) selectedStudentAccountIds.delete(id);
 const total=studentAccounts.length,chosen=selectedStudentAccountIds.size;
 $('selectedStudentAccountsCount').textContent=`Đã chọn ${chosen} / ${total} tài khoản`;
 $('deleteSelectedStudentAccounts').disabled=deletingStudentAccounts||!chosen;
 $('deleteAllStudentAccounts').disabled=deletingStudentAccounts||!total;
 const header=$('selectAllStudentAccounts');header.checked=total>0&&chosen===total;
 header.indeterminate=chosen>0&&chosen<total;
 header.disabled=deletingStudentAccounts||!total;
}
function renderStudentAccounts(){
 $('studentAccountsCount').textContent=`${studentAccounts.length} tài khoản`;
 $('studentAccountsTable').innerHTML=studentAccounts.length?studentAccounts.map(a=>`<tr><td><input type="checkbox" data-select-account="${Number(a.account_id)}" aria-label="Chọn tài khoản ${escapeHtml(a.username)}" ${selectedStudentAccountIds.has(Number(a.account_id))?'checked':''}></td><td><b>${escapeHtml(a.username)}</b></td><td>${escapeHtml(a.full_name)}</td><td>${a.status==='active'?'Đang hoạt động':escapeHtml(a.status)}</td><td>${Number(a.must_change_password)===1?'<span class="face-status no">Chưa đổi</span>':'<span class="face-status ok">Đã đổi</span>'}</td><td>${formatDate(a.created_at)}</td><td><div class="row-actions"><button class="small-btn danger" data-reset-account="${Number(a.account_id)}">Cấp lại mật khẩu</button><button class="small-btn danger" data-delete-account="${Number(a.account_id)}">Xóa</button></div></td></tr>`).join(''):'<tr><td colspan="7" class="empty">Chưa tạo tài khoản học sinh nào.</td></tr>';
 updateStudentSelection();
}
async function deleteStudentAccounts(ids,all=false){
 if(deletingStudentAccounts)return;
 const chosen=all?studentAccounts:[...new Set(ids)].map(id=>studentAccounts.find(a=>Number(a.account_id)===Number(id))).filter(Boolean);
 if(!chosen.length)return;
 const list=chosen.slice(0,5).map(a=>a.username).join(', ')+(chosen.length>5?' ...':'');
 if(!confirm(`Xóa ${chosen.length} tài khoản học sinh (${list})?\n\nChỉ xóa quyền đăng nhập; không xóa sinh viên, khuôn mặt hoặc lịch sử điểm danh. Hành động không thể hoàn tác.`))return;
 if(all){const answer=prompt(`Bạn sắp xóa TOÀN BỘ ${chosen.length} tài khoản học sinh. Nhập XOA TAT CA để xác nhận:`);if(answer!=='XOA TAT CA')return;}
 deletingStudentAccounts=true;updateStudentSelection();
 const msg=$('studentAccountsMessage');msg.textContent='Đang xóa tài khoản, vui lòng chờ...';
 try{
  const payload=all?{all:true}:{account_ids:chosen.map(a=>Number(a.account_id))};
  const result=await api('/api/admin/student-accounts/delete',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(payload)});
  selectedStudentAccountIds.clear();
  await loadStudentAccounts();
  msg.textContent=`Đã xóa ${Number(result.deleted??chosen.length)} tài khoản học sinh. Hồ sơ sinh viên và lịch sử điểm danh được giữ nguyên.`;
 }catch(e){msg.textContent='Xóa thất bại: '+e.message;}
 finally{deletingStudentAccounts=false;updateStudentSelection();}
}
async function loadStudentAccounts(){
 if(session?.user?.role!=='admin')return;
 try{const d=await api('/api/admin/student-accounts');studentAccounts=d.data||[];renderStudentAccounts();$('studentAccountsMessage').textContent='';}
 catch(e){$('studentAccountsMessage').textContent='Không tải được tài khoản học sinh: '+e.message;}
}
function showStudentCredentials(username,password){
 $('issuedStudentUsername').value=String(username||'');$('issuedStudentPassword').value=String(password||'');$('studentCredentialModal').hidden=false;
}
function hideStudentCredentials(){
 $('studentCredentialModal').hidden=true;$('issuedStudentUsername').value='';$('issuedStudentPassword').value='';
}
async function resetStudentAccountPassword(accountId){
 const account=studentAccounts.find(a=>Number(a.account_id)===Number(accountId));
 if(!account||!confirm(`Đặt lại mật khẩu cho ${account.username}? Mật khẩu cũ và các phiên đăng nhập hiện tại sẽ bị vô hiệu hóa.`))return;
 try{const d=await api(`/api/admin/student-accounts/${accountId}/reset-password`,{method:'POST'});
  if(!d.temporary_password)throw Error('API không trả về mật khẩu tạm thời.');
  showStudentCredentials(d.username,d.temporary_password);await loadStudentAccounts();
 }catch(e){$('studentAccountsMessage').textContent='Đặt lại thất bại: '+e.message;}
}
async function copyStudentCredentials(){
 const value=`Tài khoản: ${$('issuedStudentUsername').value}\nMật khẩu tạm: ${$('issuedStudentPassword').value}\nBạn phải đổi mật khẩu ngay khi đăng nhập lần đầu.`;
 try{await navigator.clipboard.writeText(value);showToast('Đã sao chép. Hãy gửi riêng cho học sinh, sau đó xóa khỏi clipboard.');}
 catch{ $('issuedStudentPassword').focus();$('issuedStudentPassword').select();showToast('Trình duyệt không cho sao chép tự động. Bạn có thể sao chép thủ công.'); }
}

// Import danh sách sinh viên từ Excel. Tất cả yêu cầu cấp mật khẩu đều gửi qua API Admin hiện tại.
let bulkStudentRows = [], bulkStudentResults = [], bulkStudentBusy = false;
function bulkStudentNotice(message){$('bulkStudentMessage').textContent=message;}
function verifySpreadsheetLibrary(){
 if(!window.XLSX){bulkStudentNotice('Không tải được thư viện Excel. Hãy kiểm tra Internet rồi tải lại trang.');return false;}
 return true;
}
function bulkReadRows(matrix){
 const headers=(matrix[0]||[]).map(v=>String(v??'').trim().toLowerCase().replace(/\s+/g,'_'));
 const getCol=(names)=>headers.findIndex(x=>names.includes(x));
 const codeCol=getCol(['student_code','ma_sinh_vien','mssv','masv']);
 const nameCol=getCol(['full_name','ho_va_ten','ho_ten','hoten']);
 const parentCol=getCol(['parent_username','tai_khoan_phu_huynh']);
 const emailCol=getCol(['parent_email','email_phu_huynh']);
 if(codeCol<0||nameCol<0||parentCol<0||emailCol<0)throw Error('Excel cần 4 cột: student_code, full_name, parent_username, parent_email.');
 const seen=new Set(),parents=new Map();
 const rows=matrix.slice(1).filter(row=>row.some(x=>String(x??'').trim())).map((row,i)=>{
  const code=String(row[codeCol]??'').trim(),name=String(row[nameCol]??'').trim();
  const parent=String(row[parentCol]??'').trim(),email=String(row[emailCol]??'').trim().toLowerCase();
  let error='';
  if(!code||!name||!parent||!email)error='Thiếu thông tin sinh viên hoặc phụ huynh';
  else if(code.length>60||name.length>180)error='Thông tin sinh viên quá dài';
  else if(!/^[a-zA-Z0-9._-]{3,60}$/.test(parent))error='parent_username không hợp lệ';
  else if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>180)error='parent_email không hợp lệ';
  else if(seen.has(code.toLowerCase()))error='Mã sinh viên trùng trong file';
  else if(parents.has(parent.toLowerCase())&&parents.get(parent.toLowerCase())!==email)error='Cùng parent_username nhưng email khác nhau';
  else if(code.toLowerCase()===parent.toLowerCase())error='Tài khoản phụ huynh trùng mã sinh viên';
  seen.add(code.toLowerCase());
  if(!error)parents.set(parent.toLowerCase(),email);
  return {line:i+2,code,name,parent,email,error};
 });
 if(!rows.length)throw Error('File Excel chưa có dữ liệu sinh viên.');
 if(rows.length>200)throw Error('Mỗi lần chỉ nhập tối đa 200 sinh viên.');
 return rows;
}
async function bulkStudentFileChanged(){
 bulkStudentRows=[];bulkStudentResults=[];$('bulkStudentCreateBtn').disabled=true;$('bulkStudentExportBtn').disabled=true;
 $('bulkStudentPreview').hidden=true;
 const file=$('bulkStudentFile').files[0];if(!file)return;
 if(!verifySpreadsheetLibrary())return;
 try{
  if(!/\.(xlsx|xls|csv)$/i.test(file.name))throw Error('Chỉ nhận file .xlsx, .xls hoặc .csv.');
  if(file.size>2*1024*1024)throw Error('File quá lớn (tối đa 2 MB).');
  const buffer=await file.arrayBuffer();
  const workbook=XLSX.read(buffer,{type:'array',raw:true});
  const matrix=XLSX.utils.sheet_to_json(workbook.Sheets[workbook.SheetNames[0]],{header:1,defval:'',raw:false});
  bulkStudentRows=bulkReadRows(matrix);
  $('bulkStudentPreviewTable').innerHTML=bulkStudentRows.slice(0,30).map(r=>`<tr><td>${r.line}</td><td>${escapeHtml(r.code)}</td><td>${escapeHtml(r.name)}</td><td>${escapeHtml(r.parent)}</td><td>${escapeHtml(r.email)}</td><td>${r.error?'<span class="face-status no">'+escapeHtml(r.error)+'</span>':'<span class="face-status ok">Hợp lệ</span>'}</td></tr>`).join('');
  $('bulkStudentPreview').hidden=false;
  const invalid=bulkStudentRows.filter(r=>r.error).length;
  bulkStudentNotice(`Đã đọc ${bulkStudentRows.length} sinh viên (${invalid} dòng lỗi). Xem trước tối đa 30 dòng. Các dòng lỗi sẽ được bỏ qua.`);
  $('bulkStudentCreateBtn').disabled=!bulkStudentRows.some(r=>!r.error);
 }catch(e){bulkStudentNotice('Không đọc được file: '+e.message);}
}
function excelSafe(v){const s=String(v??'');return /^[=+@\-\t\r]/.test(s)?"'"+s:s;}
function exportBulkStudentResults(){
 if(!bulkStudentResults.length){bulkStudentNotice('Chưa có kết quả để xuất.');return;}
 if(!verifySpreadsheetLibrary())return;
 const rows=bulkStudentResults.map((r,i)=>({
  'STT':i+1,'Mã sinh viên':excelSafe(r.code),'Họ và tên':excelSafe(r.name),
  'TK sinh viên':excelSafe(r.username),'MK tạm sinh viên':excelSafe(r.password),
  'TK phụ huynh':excelSafe(r.parent),'Email phụ huynh':excelSafe(r.email),
  'MK tạm phụ huynh':excelSafe(r.parentPassword),'Kết quả SV':excelSafe(r.status),
  'Kết quả PH':excelSafe(r.parentStatus),'Ghi chú':excelSafe(r.note)
 }));
 const ws=XLSX.utils.json_to_sheet(rows);
 ws['!cols']=[{wch:6},{wch:20},{wch:30},{wch:20},{wch:26},{wch:22},{wch:30},{wch:26},{wch:20},{wch:20},{wch:45}];
 const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'Tai khoan SV PH');
 XLSX.writeFile(wb,'tai_khoan_sinh_vien_phu_huynh_'+new Date().toISOString().slice(0,10)+'.xlsx',{compression:true,bookType:'xlsx'});
}

async function importBulkStudents(){
 if(bulkStudentBusy||!bulkStudentRows.some(r=>!r.error))return;
 const valid=bulkStudentRows.filter(r=>!r.error);
 if(!confirm(`Cấp tài khoản sinh viên và phụ huynh cho ${valid.length} dòng?\nTài khoản đã có sẽ không bị đổi mật khẩu.\nHãy chuẩn bị nơi an toàn để lưu Excel kết quả.`))return;
 bulkStudentBusy=true;
 $('bulkStudentCreateBtn').disabled=true;$('bulkStudentFile').disabled=true;
 bulkStudentResults=[];
 try{
  const [s,a]=await Promise.all([api('/api/students'),api('/api/admin/student-accounts')]);
  const map=new Map((s.data||[]).map(x=>[String(x.student_code).toLowerCase(),x]));
  const issued=new Set((a.data||[]).map(x=>String(x.username).toLowerCase()));
  for(let i=0;i<bulkStudentRows.length;i++){
   const item=bulkStudentRows[i];
   const res={code:item.code,name:item.name,parent:item.parent,email:item.email,username:'',password:'',parentPassword:'',status:'',parentStatus:'',note:''};
   bulkStudentResults.push(res);
   if(item.error){res.status='Bỏ qua';res.parentStatus='Bỏ qua';res.note=item.error;continue;}
   try{
    let student=map.get(item.code.toLowerCase());
    if(student && String(student.full_name).trim()!==item.name){
      res.status='Cần kiểm tra';res.parentStatus='Chưa liên kết';res.note='Mã sinh viên đã có nhưng họ tên khác.';
      continue;
    }
    if(!student){
      const created=await api('/api/students',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({student_code:item.code,full_name:item.name})});
      student={id:created.id,student_code:item.code,full_name:item.name};
      if(!Number(student.id))throw Error('Đã tạo sinh viên nhưng API không trả ID.');
      map.set(item.code.toLowerCase(),student);
    }
    if(issued.has(item.code.toLowerCase())){
      res.status='Đã tồn tại';res.username=item.code;
    }else{
      try{
       const account=await api('/api/admin/student-accounts',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({student_id:Number(student.id)})});
       if(!account.temporary_password)throw Error('API không trả mật khẩu sinh viên.');
       res.status='Đã tạo';res.username=String(account.username);res.password=String(account.temporary_password);
       issued.add(item.code.toLowerCase());
      }catch(e){res.status='Lỗi cấp TK SV';res.note=String(e.message||e);}
    }
    // Phụ huynh được cấp trực tiếp bởi Admin và liên kết theo student_id.
    // Khi một phụ huynh có nhiều con, chỉ hàng đầu tiên có mật khẩu mới.
    try{
      const linked=await api('/api/admin/parent-accounts/upsert-link',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:item.parent,email:item.email,student_id:Number(student.id)})});
      res.parentStatus=linked.created?'Đã tạo và liên kết':'Đã liên kết';
      if(linked.created){res.parentPassword=String(linked.temporary_password||'');}
    }catch(e){res.parentStatus='Thất bại';res.note=[res.note,String(e.message||e)].filter(Boolean).join(' | ');}
   }catch(e){res.status='Thất bại';res.parentStatus='Chưa liên kết';res.note=String(e.message||e);}
   bulkStudentNotice(`Đang xử lý ${i+1}/${bulkStudentRows.length}. Đã tạo TK sinh viên: ${bulkStudentResults.filter(x=>x.status==='Đã tạo').length}; TK phụ huynh mới: ${bulkStudentResults.filter(x=>x.parentPassword).length}.`);
   $('bulkStudentExportBtn').disabled=false;
  }
  bulkStudentNotice(`Hoàn tất ${bulkStudentRows.length} dòng. Xuất Excel và giữ kín file: mật khẩu chỉ có trong kết quả lần này. Hàng lỗi có thể xử lý rồi nhập lại mà không đổi mật khẩu cũ.`);
  exportBulkStudentResults();
  await loadData();
 }catch(e){bulkStudentNotice('Lỗi khi tải dữ liệu: '+e.message+'. Nếu đã xử lý một phần, hãy xuất danh sách mật khẩu trước khi rời trang.');}
 finally{bulkStudentBusy=false;$('bulkStudentFile').disabled=false;$('bulkStudentCreateBtn').disabled=true;$('bulkStudentExportBtn').disabled=!bulkStudentResults.length;}
}

function setupBulkStudentImport(){
 $('bulkStudentFile').addEventListener('change',bulkStudentFileChanged);
 $('bulkStudentCreateBtn').addEventListener('click',importBulkStudents);
 $('bulkStudentExportBtn').addEventListener('click',exportBulkStudentResults);

}

function setupStudentAccounts(){
 setupBulkStudentImport();
 $('reloadStudentAccounts').addEventListener('click',loadStudentAccounts);
 $('selectAllStudentAccounts').addEventListener('change',e=>{
  selectedStudentAccountIds.clear();
  if(e.target.checked)studentAccounts.forEach(a=>selectedStudentAccountIds.add(Number(a.account_id)));
  renderStudentAccounts();
 });
 $('studentAccountsTable').addEventListener('change',e=>{
  const input=e.target.closest('input[data-select-account]');if(!input)return;
  const id=Number(input.dataset.selectAccount);
  if(input.checked)selectedStudentAccountIds.add(id);else selectedStudentAccountIds.delete(id);
  updateStudentSelection();
 });
 $('studentAccountsTable').addEventListener('click',e=>{
  const reset=e.target.closest('button[data-reset-account]');
  if(reset){resetStudentAccountPassword(Number(reset.dataset.resetAccount));return;}
  const del=e.target.closest('button[data-delete-account]');
  if(del)deleteStudentAccounts([Number(del.dataset.deleteAccount)]);
 });
 $('deleteSelectedStudentAccounts').addEventListener('click',()=>deleteStudentAccounts([...selectedStudentAccountIds]));
 $('deleteAllStudentAccounts').addEventListener('click',()=>deleteStudentAccounts([],true));
 $('closeStudentCredentialBtn').addEventListener('click',hideStudentCredentials);
 $('copyStudentCredentialBtn').addEventListener('click',copyStudentCredentials);
}

function setupAuth(){
 $('passwordForm').addEventListener('submit',async e=>{e.preventDefault();try{
   await api('/api/role/change-password',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({old_password:$('oldPassword').value,new_password:$('newPassword').value})});
   $('passwordForm').reset();$('passwordGate').hidden=true;logout();setAuthMessage('loginMsg','Đã đổi mật khẩu. Hãy đăng nhập lại.',true);
 }catch(err){setAuthMessage('passwordMsg',err.message)}});
 $('cancelPassword').onclick=()=>{$('passwordForm').reset();$('passwordGate').hidden=true;logout();};
 $('loginForm').addEventListener('submit',async e=>{e.preventDefault();try{const d=await api('/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:$('loginName').value,password:$('loginPassword').value})});if(!d.token||!d.user)throw Error('API không trả về phiên đăng nhập.');$('loginPassword').value='';
 if(d.user.must_change_password){clearSessionView();session=d;$('authGate').hidden=true;$('appShell').hidden=true;$('passwordGate').hidden=false;return;}
 enterSession(d);await loadData();}catch(err){setAuthMessage('loginMsg',err.message)}});
 $('registerForm').addEventListener('submit',async e=>{e.preventDefault();try{const d=await api('/api/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:$('regName').value,email:$('regEmail').value,password:$('regPassword').value,role:$('regRole').value})});setAuthMessage('registerMsg',d.message||'Đã gửi đăng ký.',true);$('regPassword').value='';}catch(err){setAuthMessage('registerMsg',err.message)}});
 $('logoutBtn').addEventListener('click',logout);
 $('reloadRequests').addEventListener('click',loadRequests);
 $('requestsTable').addEventListener('click',e=>{const btn=e.target.closest('button[data-review]');if(btn)reviewRegistration(Number(btn.dataset.id),btn.dataset.review)});
 $('assignTeacherBtn').addEventListener('click',()=>doAssignment('teacher'));
 $('assignParentBtn').addEventListener('click',()=>doAssignment('parent'));
}
document.addEventListener('DOMContentLoaded',async()=>{
 setupNavigation();setupAuth();setupStudentAccounts();
 $('refreshBtn').addEventListener('click',loadData);$('menuBtn').addEventListener('click',()=>$('sidebar').classList.toggle('open'));
 $('studentSearch').addEventListener('input',renderStudents);$('attendanceSearch').addEventListener('input',renderAttendance);
 $('showAddStudent').addEventListener('click',()=>openStudentForm());$('cancelAddStudent').addEventListener('click',async()=>{$('addStudentForm').hidden=true;await stopFaceCamera();});$('closeStudentForm').addEventListener('click',async()=>{$('addStudentForm').hidden=true;await stopFaceCamera();});
 $('addStudentBtn').addEventListener('click',saveStudent);$('startFaceBtn').addEventListener('click',startFaceCamera);$('captureFaceBtn').addEventListener('click',captureFace);$('stopFaceBtn').addEventListener('click',stopFaceCamera);
 $('showAddClass').addEventListener('click',()=>openClassForm());$('closeClassForm').addEventListener('click',()=>$('classForm').hidden=true);$('cancelClass').addEventListener('click',()=>$('classForm').hidden=true);$('saveClassBtn').addEventListener('click',saveClass);$('getClassLocation').addEventListener('click',getClassLocation);
 await checkApi();
});

// V4 Admin additions: separate authenticated API; no tokens in localStorage.
let v4Token = null, v4RosterIds = new Set(), v4Members = new Set(), v4Schedules = [], v4Editing = null;
const v4Auth = async (path,method='GET',body) => {
 if (!v4Token) throw Error('Bạn cần đăng nhập Admin.');
 const response=await fetch(API_BASE+path,{method,headers:{'Authorization':'Bearer '+v4Token,...(body?{'Content-Type':'application/json'}:{})},...(body?{body:JSON.stringify(body)}:{})});
 const result=await response.json().catch(()=>({}));
 if(!response.ok||result.success===false){if(response.status===401||response.status===403)v4Token=null;throw Error(result.message||'HTTP '+response.status)}
 return result;
};
function v4Options(){for(const id of ['v4RosterClass','v4ScheduleClass']){
 const previous=$(id).value;$(id).innerHTML=classes.map(c=>`<option value="${Number(c.id)}">${escapeHtml(c.class_code)} – ${escapeHtml(c.class_name)}</option>`).join('');
 if(classes.some(c=>String(c.id)===previous))$(id).value=previous;
}}
function v4EnsureAuth(){v4Token=session?.user?.role==='admin'?session.token:null;if(!v4Token){showToast('Vui lòng đăng nhập Admin');return false}return true;}
async function v4LoadRoster(){if(!v4EnsureAuth())return;
 v4Options();const cls=Number($('v4RosterClass').value);if(!cls)return;
 try{const r=await v4Auth(`/api/admin/classes/${cls}/students`);v4Members=new Set((r.data||[]).map(x=>Number(x.id)));v4RosterIds=new Set();v4RenderRoster();$('v4RosterMessage').textContent='';}catch(e){$('v4RosterMessage').textContent=e.message}}
function v4RenderRoster(){const query=$('v4RosterSearch').value.trim().toLowerCase();const filtered=students.filter(s=>(s.student_code+' '+s.full_name).toLowerCase().includes(query));
 $('v4RosterStats').textContent=`${v4Members.size} sinh viên trong lớp • Đã chọn ${v4RosterIds.size} • Hiển thị ${filtered.length}`;
 $('v4RosterList').innerHTML=filtered.map(s=>`<label class="v4-student"><input type="checkbox" data-v4sid="${Number(s.id)}" ${v4RosterIds.has(Number(s.id))?'checked':''}><span><b>${escapeHtml(s.student_code)}</b> – ${escapeHtml(s.full_name)}</span><small>${v4Members.has(Number(s.id))?'✓ Đã ở trong lớp':'Chưa vào lớp'}</small></label>`).join('')||'<p>Không có sinh viên phù hợp.</p>';
 $('v4RosterList').querySelectorAll('input').forEach(el=>el.addEventListener('change',()=>{const id=Number(el.dataset.v4sid);if(el.checked)v4RosterIds.add(id);else v4RosterIds.delete(id);$('v4RosterStats').textContent=`${v4Members.size} sinh viên trong lớp • Đã chọn ${v4RosterIds.size}`;}));}
async function v4ModifyMembers(method){if(!v4EnsureAuth())return;const cls=Number($('v4RosterClass').value),ids=[...v4RosterIds];if(!ids.length){$('v4RosterMessage').textContent='Hãy chọn sinh viên trước.';return;}
 if(method==='DELETE'&&!confirm(`Gỡ ${ids.length} sinh viên khỏi lớp? Không xóa tài khoản hoặc lịch sử điểm danh.`))return;
 try{const r=await v4Auth(`/api/admin/classes/${cls}/students`,method,{student_ids:ids});await v4LoadRoster();$('v4RosterMessage').textContent=r.message||'Thành công';}catch(e){$('v4RosterMessage').textContent=e.message}}
function v4LocalIso(value){const d=new Date(value);if(!Number.isFinite(d.getTime()))throw Error('Ngày giờ không hợp lệ');return d.toISOString()}
function v4LocalInput(value){const d=new Date(value),p=n=>String(n).padStart(2,'0');return `${d.getFullYear()}-${p(d.getMonth()+1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`}
async function v4LoadSchedules(){if(!v4EnsureAuth())return;v4Options();try{const r=await v4Auth('/api/admin/schedules');v4Schedules=r.data||[];v4RenderSchedules();$('v4ScheduleMessage').textContent='';}catch(e){$('v4ScheduleMessage').textContent=e.message}}
function v4RenderSchedules(){$('v4ScheduleTable').innerHTML=v4Schedules.map(s=>`<tr><td>${escapeHtml(s.class_code)}</td><td>${escapeHtml(s.subject_name)}${s.status==='cancelled'?' (Đã hủy)':''}</td><td>${escapeHtml(s.room||'')}</td><td>${formatDate(s.starts_at)}</td><td>${formatDate(s.ends_at)}</td><td>${Number(s.attendance_duration_seconds)/60} phút · đúng giờ ${s.on_time_seconds} giây</td><td><button class="small-btn" data-edit="${Number(s.id)}">Sửa</button> <button class="small-btn danger" data-del="${Number(s.id)}">Hủy</button></td></tr>`).join('')||'<tr><td colspan="7">Chưa có lịch học.</td></tr>';
 $('v4ScheduleTable').querySelectorAll('[data-edit]').forEach(b=>b.onclick=()=>v4EditSchedule(Number(b.dataset.edit)));
 $('v4ScheduleTable').querySelectorAll('[data-del]').forEach(b=>b.onclick=()=>v4DeleteSchedule(Number(b.dataset.del)))}
function v4EditSchedule(id){const s=v4Schedules.find(x=>Number(x.id)===id);if(!s)return;v4Editing=id;$('v4ScheduleClass').value=s.class_id;$('v4Subject').value=s.subject_name;$('v4Room').value=s.room||'';$('v4Start').value=v4LocalInput(s.starts_at);$('v4End').value=v4LocalInput(s.ends_at);$('v4Duration').value=Number(s.attendance_duration_seconds)/60;$('v4OnTime').value=s.on_time_seconds;$('v4SaveSchedule').textContent='Lưu thay đổi';$('v4CancelEdit').hidden=false;window.scrollTo({top:0,behavior:'smooth'})}
function v4ResetSchedule(){v4Editing=null;$('v4SaveSchedule').textContent='+ Tạo buổi học';$('v4CancelEdit').hidden=true;$('v4Subject').value='';$('v4Room').value=''}
async function v4SaveSchedule(){if(!v4EnsureAuth())return;try{const duration=Number($('v4Duration').value)*60,ontime=Number($('v4OnTime').value),start=v4LocalIso($('v4Start').value),end=v4LocalIso($('v4End').value);
 if(!Number.isInteger(duration)||duration<60||duration>3600||!Number.isInteger(ontime)||ontime<0||ontime>=duration||new Date(end)<=new Date(start))throw Error('Thời gian điểm danh không hợp lệ.');
 const payload={class_id:Number($('v4ScheduleClass').value),subject_name:$('v4Subject').value.trim(),room:$('v4Room').value.trim(),starts_at:start,ends_at:end,attendance_duration_seconds:duration,on_time_seconds:ontime};
 if(!payload.subject_name)throw Error('Nhập tên môn học.');
 const editing=v4Editing;await v4Auth(editing?`/api/admin/schedules/${editing}`:'/api/admin/schedules',editing?'PUT':'POST',payload);v4ResetSchedule();await v4LoadSchedules();$('v4ScheduleMessage').textContent='Đã lưu thời khóa biểu.';
 }catch(e){$('v4ScheduleMessage').textContent=e.message}}
async function v4DeleteSchedule(id){if(!v4EnsureAuth()||!confirm('Hủy buổi học này? Lịch sử điểm danh được giữ lại.'))return;try{await v4Auth(`/api/admin/schedules/${id}`,'DELETE');await v4LoadSchedules()}catch(e){$('v4ScheduleMessage').textContent=e.message}}
document.addEventListener('DOMContentLoaded',()=>{
 document.querySelectorAll('[data-page="roster"],[data-page="schedule"]').forEach(b=>b.addEventListener('click',async()=>{await loadData();v4Options();if(v4EnsureAuth()){if(b.dataset.page==='roster')await v4LoadRoster();else await v4LoadSchedules()}}));
 $('v4RosterClass').onchange=v4LoadRoster;$('v4RosterSearch').oninput=v4RenderRoster;$('v4RefreshRoster').onclick=v4LoadRoster;
 $('v4RosterAll').onclick=()=>{const q=$('v4RosterSearch').value.toLowerCase().trim();students.filter(s=>(s.student_code+' '+s.full_name).toLowerCase().includes(q)).forEach(s=>v4RosterIds.add(Number(s.id)));v4RenderRoster()};
 $('v4RosterClear').onclick=()=>{v4RosterIds.clear();v4RenderRoster()};$('v4AddMembers').onclick=()=>v4ModifyMembers('POST');$('v4RemoveMembers').onclick=()=>v4ModifyMembers('DELETE');
 $('v4SaveSchedule').onclick=v4SaveSchedule;$('v4CancelEdit').onclick=v4ResetSchedule;$('v4ReloadSchedule').onclick=v4LoadSchedules;
});
