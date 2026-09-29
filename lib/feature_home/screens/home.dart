import 'package:flutter/material.dart';
import 'package:gui_lungcxr/feature_home/state/patient_state.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_footer.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_header.dart';
import 'package:gui_lungcxr/feature_home/widgets/canvas_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/chat_wid.dart';
import 'package:gui_lungcxr/feature_home/widgets/client_board.dart';
import 'package:gui_lungcxr/feature_home/widgets/sidebar_wid.dart';
import 'package:provider/provider.dart';

class Home extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final patients = context.watch<PatientState>();
    final id = patients.selected.id;

    // Editor and chat state are per patient; swap the providers on selection.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: patients.editorFor(id)),
        ChangeNotifierProvider.value(value: patients.chatFor(id)),
      ],
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          const SidebarWid(),
          const Expanded(
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                CanvasHeader(),
                Expanded(child: CanvasWid()),
                CanvasFooter(),
              ],
            ),
          ),
          SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const ClientBoard(),
                // Chat state belongs to one patient; reset scroll/input on switch.
                Expanded(child: ChatWid(key: ValueKey(id))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
