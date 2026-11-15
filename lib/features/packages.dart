import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/design.dart';
import '../main.dart';

class PackagesTab extends StatelessWidget {
  const PackagesTab({super.key,required this.state});
  final EduState state;
  @override
  Widget build(BuildContext context)=>Column(children:[
    Container(width:double.infinity,color:Palette.blue,padding:const EdgeInsets.fromLTRB(20,55,20,22),child:const Center(child:Text('Gói học & combo',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w800)))),
    Expanded(child:ListView(padding:const EdgeInsets.all(18),children:[
      const Surface(color:Color(0xFFE5EEFF),child:Row(children:[Icon(Icons.info_outline,color:Palette.blue),SizedBox(width:10),Expanded(child:Text('Chưa mở thanh toán QR hoặc chuyển khoản trong ứng dụng. Bạn có thể xem gói và gửi yêu cầu đăng ký.',style:TextStyle(fontSize:13)))])),
      const SectionHeading('Các gói đang có'),
      ...state.packages.map((pack)=>Padding(padding:const EdgeInsets.only(bottom:12),child:Surface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Icon(pack.combo?Icons.dashboard_customize_outlined:Icons.workspace_premium_outlined,color:pack.combo?Palette.purple:Palette.blue,size:25),
          const SizedBox(width:10),Expanded(child:Text(pack.title,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:16))),
          if(pack.combo) const StateTag('Combo',color:Palette.purple),
        ]),const SizedBox(height:7),Text(pack.description,style:const TextStyle(color:Palette.muted)),
        const SizedBox(height:12),Row(children:[
          Text(formatVnd(pack.price),style:const TextStyle(color:Palette.blue,fontSize:19,fontWeight:FontWeight.w800)),
          const Spacer(),Text('${pack.days} ngày',style:const TextStyle(color:Palette.muted)),
        ]),const SizedBox(height:10),
        OutlinedButton(onPressed:() async {
          if(state.repo.isDemo) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đây là dữ liệu demo. Kết nối Supabase để gửi yêu cầu gói.')));
            return;
          }
          if(state.repo.user==null){showError(context,'Vui lòng đăng nhập trước khi đăng ký gói.');return;}
          final accept=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
            title:const Text('Xác nhận yêu cầu đăng ký'),content:Text('Gửi yêu cầu về gói ${pack.title}? Việc gửi yêu cầu không đồng nghĩa đã thanh toán hoặc được cấp quyền.'),
            actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Hủy')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Gửi yêu cầu'))]));
          if(accept!=true) return;
          try{await state.repo.requestPackage(pack.id);if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã gửi yêu cầu. Chưa có thanh toán tự động.')));}catch(e){showError(context,e);}
        },child:const Text('Yêu cầu đăng ký')),
      ])))),
      if(!state.repo.isDemo&&state.repo.user!=null) ...[
        const SectionHeading('Yêu cầu của tôi'),
        FutureBuilder(future:state.repo.myOrders(),builder:(context,snap){
          if(!snap.hasData)return const Center(child:CircularProgressIndicator());
          if(snap.data!.isEmpty)return const Text('Bạn chưa gửi yêu cầu nào.');
          return Column(children:snap.data!.map((row)=>ListTile(title:Text('Gói: ${row['package_id']}'),subtitle:Text('Trạng thái: ${row['status']}'))).toList());
        }),
      ],
    ])),
  ]);
}
