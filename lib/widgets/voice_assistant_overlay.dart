import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/voice_command_service.dart';
import '../models/student_model.dart';

class VoiceAssistantOverlay extends StatefulWidget {
  final VoiceCommandService voiceService;
  final List<Student> students;
  final Function(VoiceCommand) onCommandRecognized;

  const VoiceAssistantOverlay({
    Key? key,
    required this.voiceService,
    required this.students,
    required this.onCommandRecognized,
  }) : super(key: key);

  @override
  _VoiceAssistantOverlayState createState() => _VoiceAssistantOverlayState();
}

class _VoiceAssistantOverlayState extends State<VoiceAssistantOverlay> with SingleTickerProviderStateMixin {
  String _text = "Listening...";
  bool _isProcessing = false;
  bool _isSpeaking = false;
  VoiceCommand? _pendingCommand;
  
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _startListening();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.voiceService.stop();
    widget.voiceService.stopSpeaking();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _text = _pendingCommand == null ? "Listening..." : "Say 'Yes' or 'No'...";
      _isProcessing = false;
      _isSpeaking = false;
    });
    HapticFeedback.lightImpact();
    
    widget.voiceService.listen(
      students: widget.students,
      onResult: (text) {
        setState(() {
          _text = text;
        });
      },
      onCommandRecognized: _handleCommand,
    );
  }

  void _handleCommand(VoiceCommand command) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
      _text = "Processing...";
    });

    if (command.error != null) {
      setState(() => _text = "Error: ${command.error}");
      await widget.voiceService.speak("Sorry, I didn't catch that.");
      Future.delayed(Duration(seconds: 2), () => Navigator.pop(context));
      return;
    }

    if (_pendingCommand == null) {
      if (command.intent == VoiceIntent.markAttendance || command.intent == VoiceIntent.checkDues) {
        if (command.student != null) {
          _pendingCommand = command;
          await _askForConfirmation(command.student!.name);
        } else {
          setState(() => _text = "Could not find student.");
          await widget.voiceService.speak("I couldn't find that student.");
           Future.delayed(Duration(seconds: 2), () => Navigator.pop(context));
        }
      } else {
        setState(() => _text = "Unknown command.");
        await widget.voiceService.speak("I didn't understand.");
        Future.delayed(Duration(seconds: 2), () => Navigator.pop(context));
      }
    } 
    else {
      if (command.intent == VoiceIntent.confirmation) {
        setState(() => _text = "Confirmed!");
        await widget.voiceService.speak("Okay, done.");
        widget.onCommandRecognized(_pendingCommand!);
      } else if (command.intent == VoiceIntent.rejection) {
        setState(() => _text = "Cancelled.");
        await widget.voiceService.speak("Cancelled.");
        Future.delayed(Duration(seconds: 1), () => Navigator.pop(context));
      } else {
        await widget.voiceService.speak("Please say Yes or No.");
        _startListening();
      }
    }
  }

  Future<void> _askForConfirmation(String studentName) async {
    setState(() {
      _isProcessing = false;
      _isSpeaking = true;
      _text = "Did you mean $studentName?";
    });
    
    await widget.voiceService.speak("Did you mean $studentName?");
    await widget.voiceService.speak("Did you mean $studentName?");
    
    _startListening();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A237E),
            Color(0xFF311B92),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 30),
          
          ScaleTransition(
            scale: _animation,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isSpeaking ? Colors.amber.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: _isSpeaking ? Colors.amberAccent.withOpacity(0.3) : Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: Icon(
                _isSpeaking ? Icons.volume_up : Icons.mic, 
                size: 48, 
                color: Colors.white,
              ),
            ),
          ),
          
          SizedBox(height: 30),
          
          Text(
            _text,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 24, 
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          
          SizedBox(height: 10),
          if (!_isProcessing && !_isSpeaking)
            Text(
              _pendingCommand == null ? "Try 'Mark Rahul Present'" : "Say 'Yes' to confirm", 
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
            
          SizedBox(height: 30),
          
          if (_isProcessing)
            LinearProgressIndicator(
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
            ),
            
          SizedBox(height: 20),
          
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.white70)),
          )
        ],
      ),
    );
  }
}
