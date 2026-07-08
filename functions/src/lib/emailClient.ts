import * as nodemailer from "nodemailer";

/**
 * Thin wrapper over Gmail SMTP (a dedicated sending account + App
 * Password — see EMAIL_USER/EMAIL_APP_PASSWORD in config.ts), used only
 * for MP credential-delivery emails (first-time setup + forgot-
 * credentials, see functions/src/officials/). Not built for bulk/
 * marketing volume — Gmail rate-limits sending; fine for a few dozen MPs.
 */
export class EmailClient {
  private readonly transporter: nodemailer.Transporter;

  constructor(user: string, appPassword: string) {
    this.transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {user, pass: appPassword},
    });
  }

  async sendCredentials(input: {
    to: string;
    constituencyName: string;
    loginId: string;
    password: string;
  }): Promise<void> {
    await this.transporter.sendMail({
      from: `"Praja Dhvani" <${(this.transporter.options as {auth?: {user?: string}}).auth?.user}>`,
      to: input.to,
      subject: `Your Praja Dhvani MP login — ${input.constituencyName}`,
      html: `
        <p>Hello,</p>
        <p>Here are your Praja Dhvani MP dashboard login credentials for <b>${input.constituencyName}</b>:</p>
        <p>
          <b>Login ID:</b> ${input.loginId}<br/>
          <b>Password:</b> ${input.password}
        </p>
        <p>Open the app, tap the "MP office" tab, and sign in with the Login ID above as your Constituency ID.</p>
        <p>If you didn't request this, please ignore this email — your credentials were not shared with anyone else.</p>
        <p>— Praja Dhvani</p>
      `,
    });
  }
}
