import 'dart:typed_data';
// import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:pushtrial/api/api.dart';
import 'package:pushtrial/models/payments.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/school_info.dart';
// import 'package:image/image.dart' as img;
// import 'package:file_picker/file_picker.dart';
// import 'package:http/http.dart' as http;

class PaymentForm extends StatefulWidget {
  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  User user = UserData.myUser;
  String? _selectedPaymentType;
  String? _selectedSY;
  String? _selectedSem;
  List<PaymentOptions> _paymentOptions = [];
  List<Bank> _bankOptions = [];
  List<SY> _syOptions = [];
  List<Semester> _semesterOptions = [];
  List<Contact> _contactOptions = [];
  int id = 0;
  Uint8List? _receiptImageBytes;
  File? _receiptImageFile;
  bool loading = true;
  List<SchoolInfo> schoolInfo = [];
  Color schoolColor = const Color.fromARGB(0, 255, 255, 255);

  // Bumped after a successful submit so the selects (which only read their initial value)
  // start over from empty.
  int _resetCount = 0;

  final List<String> _messageReceiverOptions = [
    'Student',
    'Mother',
    'Father',
    'Guardian',
  ];

  String? getContactNumber(String receiver) {
    if (_contactOptions.isEmpty) return null;

    final contact = _contactOptions.first;
    switch (receiver) {
      case 'Student':
        return contact.contactno;
      case 'Mother':
        return contact.mcontactno;
      case 'Father':
        return contact.fcontactno;
      case 'Guardian':
        return contact.gcontactno;
      default:
        return null;
    }
  }

  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _transactionDateController =
      TextEditingController();
  final TextEditingController _referenceNumberController =
      TextEditingController();
  final TextEditingController _paymentAmountController =
      TextEditingController();
  final TextEditingController _messageReceiverController =
      TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();

  Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7 || hexString.length == 9) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> getSchoolInfo() async {
    final response = await CallApi().getSchoolInfo();

    final parsedResponse = json.decode(response.body);
    if (parsedResponse is List) {
      setState(() {
        schoolInfo = parsedResponse
            .map((model) => SchoolInfo.fromJson(model))
            .toList()
            .cast<SchoolInfo>();

        schoolColor = hexToColor(schoolInfo[0].schoolcolor);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _transactionDateController.dispose();
    _referenceNumberController.dispose();
    _paymentAmountController.dispose();
    _messageReceiverController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() {
      loading = true;
    });

    await getUser();
    await getOnlinePayments();
    getSchoolInfo();

    setState(() {
      loading = false;
    });
  }

  Future<void> getUser() async {
    SharedPreferences preferences = await SharedPreferences.getInstance();
    final json = preferences.getString('user');
    user = json == null ? UserData.myUser : User.fromJson(jsonDecode(json));

    setState(() {
      id = user.id;
    });
  }

  Future<void> getOnlinePayments() async {
    final response = await CallApi().getOnlinePaymentsOptions(id);
    final Map<String, dynamic> responseData = json.decode(response.body);

    _paymentOptions = (responseData['onlinepaymentoptions'] as List)
        .map((data) => PaymentOptions.fromJson(data))
        .toList();

    _bankOptions = (responseData['bank'] as List)
        .map((data) => Bank.fromJson(data))
        .toList();

    _syOptions = (responseData['sy'] as List)
        .map((data) => SY.fromJson(data))
        .toList();

    _semesterOptions = (responseData['semester'] as List)
        .map((data) => Semester.fromJson(data))
        .toList();

    _contactOptions = (responseData['contact'] as List)
        .map((data) => Contact.fromJson(data))
        .toList();

    if (_paymentOptions.isNotEmpty) {
      _selectedPaymentType = _paymentOptions.first.description;
    }

    var activeYear = _syOptions.firstWhere((year) => year.isactive == 1);
    var activeSem = _semesterOptions.firstWhere((sem) => sem.isactive == 1);

    if (_syOptions.isNotEmpty && _semesterOptions.isNotEmpty) {
      _selectedSY = activeYear.sydesc;
      _selectedSem = activeSem.semester;
    }

    setState(() {});
  }

  Future<Uint8List?> pickImage() async {
    // Use file_picker for gallery access (Google Play compliant)
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final imageFile = File(result.files.single.path!);
      return await imageFile.readAsBytes();
    }
    return null;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    final toaster = ShadToaster.of(context);
    toaster.show(
      error
          ? ShadToast.destructive(description: Text(message))
          : ShadToast(description: Text(message)),
    );
  }

  Future<void> _handlePickImage() async {
    // Use file_picker for image selection (Google Play compliant)
    File? imageFile;
    Uint8List? imageBytes;

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        imageFile = File(result.files.single.path!);
        imageBytes = await imageFile.readAsBytes();

        setState(() {
          _receiptImageBytes = imageBytes;
          _receiptImageFile = imageFile;
        });
      } else {
        print('No image selected.');
      }
    } catch (e) {
      print('Error selecting image: $e');
      _toast('Error selecting image: $e', error: true);
    }
  }

  void _clearForm() {
    _transactionDateController.clear();
    _referenceNumberController.clear();
    _paymentAmountController.clear();
    _messageReceiverController.clear();
    _contactNumberController.clear();
    _receiptImageFile = null;
    _receiptImageBytes = null;
    setState(() {
      _selectedPaymentType = null;
      _resetCount++;
    });
  }

  Future<void> _submitForm() async {
    if (_selectedPaymentType == null ||
        _transactionDateController.text.isEmpty ||
        _referenceNumberController.text.isEmpty ||
        _paymentAmountController.text.isEmpty ||
        _messageReceiverController.text.isEmpty ||
        _contactNumberController.text.isEmpty) {
      _toast('Please fill in all required fields.', error: true);
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      String amount = _paymentAmountController.text;
      String transDate = _transactionDateController.text;
      String refNum = _referenceNumberController.text;
      String opcontact = _contactNumberController.text;
      String syid = _syOptions
          .firstWhere((sy) => sy.sydesc == _selectedSY)
          .id
          .toString();
      String semid = _semesterOptions
          .firstWhere((sem) => sem.semester == _selectedSem)
          .id
          .toString();

      String? paymentType = _paymentOptions
          .firstWhere((option) => option.description == _selectedPaymentType)
          .id
          .toString();

      var response = await CallApi().getSendPayment(
        id.toString(),
        paymentType,
        amount,
        transDate,
        refNum,
        opcontact,
        syid,
        semid,
        _receiptImageFile,
      );

      if (response.statusCode == 200) {
        String responseString = await response.stream.bytesToString();
        print('Response: $responseString');

        if (responseString.trim().startsWith('{')) {
          var responseData = json.decode(responseString);

          if (responseData['status'] == 0 &&
              responseData['message'] == 'Reference Number already exists') {
            _toast('Reference number already exists.', error: true);
          } else {
            _toast('Payment submitted successfully!');
            _clearForm();
          }
        } else {
          _toast('Payment submitted successfully!');
          _clearForm();
        }
      } else {
        final responseString = await response.stream.bytesToString();

        _toast('Failed to submit payment: $responseString', error: true);
      }
    } catch (e) {
      _toast('An error occurred. Please try again later.', error: true);
    } finally {
      setState(() {
        loading = false;
        _receiptImageFile = null;
      });
    }
  }

  // Label above a form control, with the standard gap below.
  Widget _field(String label, Widget control) {
    final text = ShadTheme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.small.copyWith(fontWeight: FontWeight.w500)),
          Gap.hSm,
          control,
        ],
      ),
    );
  }

  Widget _icon(IconData icon) {
    final color = ShadTheme.of(context).colorScheme.mutedForeground;
    return Icon(icon, size: IconSize.row, color: color);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppPage(title: 'Online payment form', body: LoadingSkeleton());
    }
    final theme = ShadTheme.of(context);
    final hasReceipt = _receiptImageBytes != null;

    return AppPage(
      title: 'Online payment form',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                'School year',
                ShadSelect<String>(
                  placeholder: const Text('Select school year'),
                  initialValue: _selectedSY,
                  options: [
                    for (final option in _syOptions)
                      ShadOption(value: option.sydesc, child: Text(option.sydesc)),
                  ],
                  selectedOptionBuilder: (context, value) => Text(value),
                  onChanged: (value) {
                    setState(() {
                      _selectedSY = value;
                    });
                  },
                ),
              ),
            ),
            Gap.wSm,
            Expanded(
              child: _field(
                'Semester',
                ShadSelect<String>(
                  placeholder: const Text('Select semester'),
                  initialValue: _selectedSem,
                  options: [
                    for (final option in _semesterOptions)
                      ShadOption(value: option.semester, child: Text(option.semester)),
                  ],
                  selectedOptionBuilder: (context, value) => Text(value),
                  onChanged: (value) {
                    setState(() {
                      _selectedSem = value;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        _field(
          'Payment type',
          ShadSelect<String>(
            key: ValueKey('type-$_resetCount'),
            placeholder: const Text('Select payment type'),
            initialValue: _selectedPaymentType,
            options: [
              for (final option in _paymentOptions)
                ShadOption(value: option.description, child: Text(option.description)),
            ],
            selectedOptionBuilder: (context, value) => Row(
              children: [
                _icon(LucideIcons.banknote),
                Gap.wSm,
                Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
              ],
            ),
            onChanged: (value) {
              setState(() {
                _selectedPaymentType = value;
              });
            },
          ),
        ),
        if (_selectedPaymentType == 'BANK')
          _field(
            'Bank name',
            ShadSelect<String>(
              key: ValueKey('bank-$_resetCount'),
              placeholder: const Text('Select bank'),
              initialValue: _bankNameController.text.isEmpty ? null : _bankNameController.text,
              options: [
                for (final option in _bankOptions)
                  ShadOption(value: option.optionDescription, child: Text(option.optionDescription)),
              ],
              selectedOptionBuilder: (context, value) => Row(
                children: [
                  _icon(LucideIcons.landmark),
                  Gap.wSm,
                  Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
                ],
              ),
              onChanged: (value) {
                setState(() {
                  _bankNameController.text = value!;
                });
              },
            ),
          ),
        _field(
          'Bank transaction date',
          ShadInput(
            controller: _transactionDateController,
            placeholder: const Text('MM/DD/YYYY'),
            leading: _icon(LucideIcons.calendarDays),
          ),
        ),
        _field(
          'Reference number',
          ShadInput(
            controller: _referenceNumberController,
            placeholder: const Text('Reference number'),
            leading: _icon(LucideIcons.hash),
          ),
        ),
        _field(
          'Payment amount',
          ShadInput(
            controller: _paymentAmountController,
            placeholder: const Text('0.00'),
            leading: _icon(LucideIcons.banknote),
            keyboardType: TextInputType.number,
          ),
        ),
        _field(
          'Message receiver',
          ShadSelect<String>(
            key: ValueKey('receiver-$_resetCount'),
            placeholder: const Text('Select receiver'),
            initialValue: _messageReceiverController.text.isEmpty ? null : _messageReceiverController.text,
            options: [
              for (final option in _messageReceiverOptions)
                ShadOption(value: option, child: Text(option)),
            ],
            selectedOptionBuilder: (context, value) => Row(
              children: [
                _icon(LucideIcons.messageSquare),
                Gap.wSm,
                Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
              ],
            ),
            onChanged: (value) {
              setState(() {
                _messageReceiverController.text = value!;
                _contactNumberController.text = getContactNumber(
                  value,
                )!;
              });
            },
          ),
        ),
        _field(
          'Contact number',
          ShadInput(
            controller: _contactNumberController,
            placeholder: const Text('Contact number'),
            leading: _icon(LucideIcons.phone),
            keyboardType: TextInputType.phone,
          ),
        ),
        _field(
          'Receipt',
          ShadButton.outline(
            width: double.infinity,
            onPressed: _handlePickImage,
            leading: Icon(
              hasReceipt ? LucideIcons.circleCheck : LucideIcons.imagePlus,
              size: IconSize.row,
            ),
            child: Text(hasReceipt ? 'Receipt image selected' : 'Select receipt image from gallery'),
          ),
        ),
        if (hasReceipt)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: ClipRRect(
              borderRadius: theme.radius,
              child: Image.memory(
                _receiptImageBytes!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        Gap.hSm,
        ShadButton(
          width: double.infinity,
          onPressed: _submitForm,
          leading: const Icon(LucideIcons.upload, size: IconSize.row),
          child: const Text('Submit payment'),
        ),
      ],
    );
  }
}
